import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../zettel/domain/entities/inbox_item.dart';
import '../../domain/services/capture_intake.dart';
import '../../domain/usecases/capture_from_clipboard.dart';
import '../../domain/usecases/ensure_stt_model.dart';

/// Where a seeding preview flow starts from (dial chip or shortcut).
sealed class SeedSource extends Equatable {
  const SeedSource();

  @override
  List<Object?> get props => const [];
}

/// « Coller » : the system pasteboard is read when the flow opens.
final class ClipboardSeedSource extends SeedSource {
  const ClipboardSeedSource();
}

/// « Ajouter un fichier » : a file already picked by the user.
final class FileSeedSource extends SeedSource {
  const FileSeedSource(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

sealed class SeedIntakeState extends Equatable {
  const SeedIntakeState();

  @override
  List<Object?> get props => const [];
}

/// Extraction (clipboard read, OCR, transcription) in progress.
/// [modelProgress] is set while the STT model downloads on first use.
final class SeedIntakeAnalyzing extends SeedIntakeState {
  const SeedIntakeAnalyzing({this.modelProgress});

  final double? modelProgress;

  @override
  List<Object?> get props => [modelProgress];
}

/// The analyzed draft is under review on the preview screen.
final class SeedIntakeReady extends SeedIntakeState {
  const SeedIntakeReady({
    required this.draft,
    this.sowing = false,
    this.errorMessage,
  });

  final SeedDraft draft;

  /// True while the draft is being written to the inbox.
  final bool sowing;

  /// Transient inline error (failed sow); the draft stays editable.
  final String? errorMessage;

  /// Note: [errorMessage] is transient and intentionally NOT carried
  /// over — any copy clears it unless a new message is provided.
  SeedIntakeReady copyWith({
    SeedDraft? draft,
    bool? sowing,
    String? errorMessage,
  }) {
    return SeedIntakeReady(
      draft: draft ?? this.draft,
      sowing: sowing ?? this.sowing,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [draft, sowing, errorMessage];
}

/// Terminal success: the enriched draft landed in the inbox nursery.
final class SeedIntakeSown extends SeedIntakeState {
  const SeedIntakeSown(this.item);

  final InboxItem item;

  @override
  List<Object?> get props => [item];
}

/// Terminal error with a user-presentable message.
final class SeedIntakeFailed extends SeedIntakeState {
  const SeedIntakeFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Drives the « aperçu avant semis » screen: reads/analyzes the payload
/// through [CaptureIntake], lets the user edit the proposed draft, then
/// sows it into the inbox nursery.
@injectable
class SeedIntakeCubit extends Cubit<SeedIntakeState> {
  SeedIntakeCubit(
    this._intake,
    this._captureFromClipboard,
    this._ensureSttModel,
  ) : super(const SeedIntakeAnalyzing());

  final CaptureIntake _intake;
  final CaptureFromClipboard _captureFromClipboard;
  final EnsureSttModel _ensureSttModel;

  Future<void> start(SeedSource source) async {
    switch (source) {
      case ClipboardSeedSource():
        final read = await _captureFromClipboard(const NoParams());
        if (isClosed) return;
        await read.fold(
          (failure) async => emit(SeedIntakeFailed(failure.message)),
          (content) => _analyze(ClipboardPayload(content)),
        );
      case FileSeedSource(:final path):
        final payload = FilePayload(path);
        // Transcription needs the STT model: surface the first-use
        // download progress before extracting, like the audio flow did.
        if (_intake.detectKind(payload) == SeedKind.audio &&
            !await _ensureModelReady()) {
          return;
        }
        await _analyze(payload);
    }
  }

  void textChanged(String text) {
    final current = state;
    if (current is! SeedIntakeReady || current.sowing) return;
    emit(current.copyWith(draft: current.draft.copyWith(text: text)));
  }

  void titleChanged(String title) {
    final current = state;
    if (current is! SeedIntakeReady || current.sowing) return;
    emit(current.copyWith(draft: current.draft.copyWith(title: title)));
  }

  void tagRemoved(String tag) {
    final current = state;
    if (current is! SeedIntakeReady || current.sowing) return;
    final tags = current.draft.tags.where((t) => t != tag).toList();
    emit(current.copyWith(draft: current.draft.copyWith(tags: tags)));
  }

  Future<void> sow() async {
    final current = state;
    if (current is! SeedIntakeReady || current.sowing) return;
    emit(current.copyWith(sowing: true));
    final result = await _intake.sow(current.draft);
    if (isClosed) return;
    result.fold(
      // Keep the user's edits reviewable: inline error, not terminal.
      (failure) => emit(
        current.copyWith(
          sowing: false,
          errorMessage:
              'Le semis a échoué (${failure.message}). Vos modifications '
              'sont conservées : vous pouvez réessayer.',
        ),
      ),
      (item) => emit(SeedIntakeSown(item)),
    );
  }

  Future<void> _analyze(CapturePayload payload) async {
    emit(const SeedIntakeAnalyzing());
    final result = await _intake.analyze(payload);
    if (isClosed) return;
    result.fold(
      (failure) => emit(SeedIntakeFailed(failure.message)),
      (draft) => emit(SeedIntakeReady(draft: draft)),
    );
  }

  /// Streams the STT model download when needed. Returns false (after
  /// emitting a [SeedIntakeFailed]) when installation failed.
  Future<bool> _ensureModelReady() async {
    await for (final either in _ensureSttModel(const NoParams())) {
      if (isClosed) return false;
      final failed = either.fold(
        (failure) {
          emit(SeedIntakeFailed(failure.message));
          return true;
        },
        (progress) {
          if (progress < 1.0) {
            emit(SeedIntakeAnalyzing(modelProgress: progress));
          }
          return false;
        },
      );
      if (failed) return false;
    }
    return true;
  }
}
