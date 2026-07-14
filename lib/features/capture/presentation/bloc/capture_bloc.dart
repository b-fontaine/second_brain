// Named constructor parameters (for readable DI and tests) assigned to
// private fields cannot use initializing formals.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart' show Either, Left;
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../assistant/domain/entities/zettel_draft.dart';
import '../../../zettel/domain/entities/inbox_item.dart';
import '../../domain/services/transcription_service.dart';
import '../../domain/usecases/accept_draft.dart';
import '../../domain/usecases/capture_from_clipboard.dart';
import '../../domain/usecases/ensure_stt_model.dart';
import '../../domain/usecases/process_capture.dart';
import '../../domain/usecases/recognize_screenshot.dart';
import '../../domain/usecases/start_dictation.dart';
import '../../domain/usecases/stop_dictation.dart';
import '../../domain/usecases/transcribe_audio_file.dart';
import 'dictation_transcript.dart';

part 'capture_event.dart';
part 'capture_state.dart';

/// Orchestrates the capture flow for the four ingestion assistants:
/// source → extraction (with model-download progress) → editable text →
/// assistant drafts → review (accept / accept all / reject).
@injectable
class CaptureBloc extends Bloc<CaptureEvent, CaptureState> {
  CaptureBloc({
    required CaptureFromClipboard captureFromClipboard,
    required TranscribeAudioFile transcribeAudioFile,
    required RecognizeScreenshot recognizeScreenshot,
    required ProcessCapture processCapture,
    required AcceptDraft acceptDraft,
    required StartDictation startDictation,
    required StopDictation stopDictation,
    required EnsureSttModel ensureSttModel,
  }) : _captureFromClipboard = captureFromClipboard,
       _transcribeAudioFile = transcribeAudioFile,
       _recognizeScreenshot = recognizeScreenshot,
       _processCapture = processCapture,
       _acceptDraft = acceptDraft,
       _startDictation = startDictation,
       _stopDictation = stopDictation,
       _ensureSttModel = ensureSttModel,
       super(const CaptureIdle()) {
    on<CaptureClipboardRequested>(_onClipboardRequested);
    on<CaptureAudioFilePicked>(_onAudioFilePicked);
    on<CaptureScreenshotPicked>(_onScreenshotPicked);
    on<CapturePasteImageRequested>(_onPasteImageRequested);
    on<CaptureDictationStarted>(_onDictationStarted);
    on<CaptureDictationStopped>(_onDictationStopped);
    on<_CaptureDictationSegmentReceived>(_onDictationSegmentReceived);
    on<CaptureTextChanged>(_onTextChanged);
    on<CaptureOrganizeRequested>(_onOrganizeRequested);
    on<CaptureSaveToInboxRequested>(_onSaveToInboxRequested);
    on<CaptureDraftChanged>(_onDraftChanged);
    on<CaptureDraftAccepted>(_onDraftAccepted);
    on<CaptureAcceptAllRequested>(_onAcceptAllRequested);
    on<CaptureDraftsRejected>(_onDraftsRejected);
    on<CaptureReset>(_onReset);
  }

  final CaptureFromClipboard _captureFromClipboard;
  final TranscribeAudioFile _transcribeAudioFile;
  final RecognizeScreenshot _recognizeScreenshot;
  final ProcessCapture _processCapture;
  final AcceptDraft _acceptDraft;
  final StartDictation _startDictation;
  final StopDictation _stopDictation;
  final EnsureSttModel _ensureSttModel;

  StreamSubscription<Either<Failure, DictationSegment>>? _dictationSub;

  /// Guards against concurrent [CaptureDictationStarted] handling: the
  /// bloc's default event transformer is concurrent and the state-based
  /// guard alone is evaluated before the first await, so a double-tap
  /// could start two dictation sessions. Set synchronously before the
  /// first await, cleared when the handler completes.
  bool _dictationStarting = false;

  Future<void> _onClipboardRequested(
    CaptureClipboardRequested event,
    Emitter<CaptureState> emit,
  ) async {
    emit(const CaptureExtracting(CaptureType.clipboard));
    final result = await _captureFromClipboard(const NoParams());
    await result.fold<Future<void>>(
      (failure) async => emit(CaptureFailed(failure.message)),
      (content) async {
        final text = content.text;
        if (text != null && text.trim().isNotEmpty) {
          emit(CaptureTextEditing(type: CaptureType.clipboard, text: text));
          return;
        }
        final imagePath = content.imagePath;
        if (imagePath != null) {
          await _runOcr(emit, imagePath, type: CaptureType.clipboard);
          return;
        }
        emit(const CaptureFailed('Le presse-papiers est vide'));
      },
    );
  }

  Future<void> _onAudioFilePicked(
    CaptureAudioFilePicked event,
    Emitter<CaptureState> emit,
  ) async {
    if (!await _ensureModelReady(emit, CaptureType.audio)) return;
    emit(const CaptureExtracting(CaptureType.audio));
    final result = await _transcribeAudioFile(
      TranscribeAudioFileParams(event.path),
    );
    result.fold(
      (failure) => emit(CaptureFailed(failure.message)),
      (text) => emit(
        CaptureTextEditing(
          type: CaptureType.audio,
          text: text,
          assetPath: event.path,
        ),
      ),
    );
  }

  Future<void> _onScreenshotPicked(
    CaptureScreenshotPicked event,
    Emitter<CaptureState> emit,
  ) async {
    emit(const CaptureExtracting(CaptureType.screenshot));
    await _runOcr(emit, event.path, type: CaptureType.screenshot);
  }

  Future<void> _onPasteImageRequested(
    CapturePasteImageRequested event,
    Emitter<CaptureState> emit,
  ) async {
    emit(const CaptureExtracting(CaptureType.screenshot));
    final result = await _captureFromClipboard(const NoParams());
    await result.fold<Future<void>>(
      (failure) async => emit(CaptureFailed(failure.message)),
      (content) async {
        final imagePath = content.imagePath;
        if (imagePath == null) {
          emit(
            const CaptureFailed(
              "Aucune image dans le presse-papiers. Copiez d'abord une "
              "capture d'écran, puis réessayez.",
            ),
          );
          return;
        }
        await _runOcr(emit, imagePath, type: CaptureType.screenshot);
      },
    );
  }

  Future<void> _runOcr(
    Emitter<CaptureState> emit,
    String imagePath, {
    required CaptureType type,
  }) async {
    final result = await _recognizeScreenshot(
      RecognizeScreenshotParams(imagePath),
    );
    result.fold(
      (failure) => emit(CaptureFailed(failure.message)),
      (text) => emit(
        CaptureTextEditing(type: type, text: text, assetPath: imagePath),
      ),
    );
  }

  /// Streams the model download when needed. Returns false (after emitting
  /// a [CaptureFailed]) when installation failed.
  Future<bool> _ensureModelReady(
    Emitter<CaptureState> emit,
    CaptureType type,
  ) async {
    var succeeded = true;
    await for (final either in _ensureSttModel(const NoParams())) {
      either.fold(
        (failure) {
          succeeded = false;
          emit(CaptureFailed(failure.message));
        },
        (progress) {
          if (progress < 1.0) {
            emit(CaptureModelInstalling(type: type, progress: progress));
          }
        },
      );
      if (!succeeded) break;
    }
    return succeeded;
  }

  Future<void> _onDictationStarted(
    CaptureDictationStarted event,
    Emitter<CaptureState> emit,
  ) async {
    if (_dictationStarting || state is CaptureDictationRunning) return;
    _dictationStarting = true;
    try {
      if (!await _ensureModelReady(emit, CaptureType.dictation)) return;

      emit(const CaptureDictationRunning(DictationTranscript()));
      await _dictationSub?.cancel();
      _dictationSub = _startDictation(const NoParams()).listen(
        (either) => add(_CaptureDictationSegmentReceived(either)),
        onError: (Object error, StackTrace _) => add(
          _CaptureDictationSegmentReceived(
            Left(TranscriptionFailure(error.toString())),
          ),
        ),
      );
    } finally {
      _dictationStarting = false;
    }
  }

  // Kept synchronous: bloc's default event transformer is concurrent, and
  // an await between reading [state] and emitting could interleave two
  // segment events and drop a committed utterance.
  void _onDictationSegmentReceived(
    _CaptureDictationSegmentReceived event,
    Emitter<CaptureState> emit,
  ) {
    final current = state;
    // Late segments after stop/reset are ignored on purpose.
    if (current is! CaptureDictationRunning) return;
    event.result.fold(
      (failure) {
        unawaited(_cancelDictation());
        emit(CaptureFailed(failure.message));
      },
      (segment) {
        emit(CaptureDictationRunning(current.transcript.apply(segment)));
      },
    );
  }

  Future<void> _onDictationStopped(
    CaptureDictationStopped event,
    Emitter<CaptureState> emit,
  ) async {
    final current = state;
    if (current is! CaptureDictationRunning) return;
    await _cancelDictation();
    final text = current.transcript.fullText;
    if (text.trim().isEmpty) {
      emit(const CaptureFailed("Aucune parole n'a été détectée"));
    } else {
      emit(CaptureTextEditing(type: CaptureType.dictation, text: text));
    }
  }

  void _onTextChanged(CaptureTextChanged event, Emitter<CaptureState> emit) {
    final current = state;
    if (current is CaptureTextEditing) {
      emit(
        CaptureTextEditing(
          type: current.type,
          text: event.text,
          assetPath: current.assetPath,
        ),
      );
    }
  }

  Future<void> _onOrganizeRequested(
    CaptureOrganizeRequested event,
    Emitter<CaptureState> emit,
  ) async {
    final (type, text, assetPath) = switch (state) {
      CaptureTextEditing(:final type, :final text, :final assetPath) => (
        type,
        text,
        assetPath,
      ),
      CaptureAssistantUnavailable(:final type, :final text, :final assetPath) =>
        (type, text, assetPath),
      _ => (null, '', null),
    };
    if (type == null) return;
    if (text.trim().isEmpty) {
      emit(const CaptureFailed('Le texte à organiser est vide'));
      return;
    }
    emit(CaptureOrganizing(type: type, text: text, assetPath: assetPath));
    final result = await _processCapture(
      ProcessCaptureParams(rawText: text, type: type, assetPath: assetPath),
    );
    result.fold(
      (failure) {
        if (failure is AiFailure) {
          emit(
            CaptureAssistantUnavailable(
              type: type,
              text: text,
              assetPath: assetPath,
              message: failure.message,
            ),
          );
        } else {
          emit(CaptureFailed(failure.message));
        }
      },
      (outcome) {
        if (outcome.drafts.isEmpty) {
          emit(
            CaptureSuccess(
              message:
                  outcome.assistantMessage ??
                  "Capture enregistrée dans l'inbox.",
            ),
          );
        } else {
          emit(CaptureDraftsReview(item: outcome.item, drafts: outcome.drafts));
        }
      },
    );
  }

  Future<void> _onSaveToInboxRequested(
    CaptureSaveToInboxRequested event,
    Emitter<CaptureState> emit,
  ) async {
    final (type, text, assetPath) = switch (state) {
      CaptureTextEditing(:final type, :final text, :final assetPath) => (
        type,
        text,
        assetPath,
      ),
      CaptureAssistantUnavailable(:final type, :final text, :final assetPath) =>
        (type, text, assetPath),
      _ => (null, '', null),
    };
    if (type == null) return;
    emit(CaptureOrganizing(type: type, text: text, assetPath: assetPath));
    final result = await _processCapture(
      ProcessCaptureParams(
        rawText: text,
        type: type,
        assetPath: assetPath,
        proposeDrafts: false,
      ),
    );
    result.fold(
      (failure) => emit(CaptureFailed(failure.message)),
      (_) => emit(
        const CaptureSuccess(message: "Capture enregistrée dans l'inbox."),
      ),
    );
  }

  void _onDraftChanged(CaptureDraftChanged event, Emitter<CaptureState> emit) {
    final current = state;
    if (current is! CaptureDraftsReview || current.accepting) return;
    if (event.index < 0 || event.index >= current.drafts.length) return;
    final drafts = List<ZettelDraft>.of(current.drafts);
    drafts[event.index] = event.draft;
    emit(current.copyWith(drafts: drafts));
  }

  Future<void> _onDraftAccepted(
    CaptureDraftAccepted event,
    Emitter<CaptureState> emit,
  ) async {
    final current = state;
    if (current is! CaptureDraftsReview || current.accepting) return;
    if (event.index < 0 || event.index >= current.drafts.length) return;
    emit(current.copyWith(accepting: true));

    final draft = current.drafts[event.index];
    final result = await _acceptDraft(
      AcceptDraftParams(draft: draft, item: current.item),
    );
    result.fold(
      // A transient failure must not throw away the remaining drafts and
      // the user's edits: stay in review with an inline error.
      (failure) => emit(
        current.copyWith(
          accepting: false,
          errorMessage: _acceptFailedMessage(failure),
        ),
      ),
      (_) {
        final remaining = List<ZettelDraft>.of(current.drafts)
          ..removeAt(event.index);
        final accepted = current.acceptedCount + 1;
        if (remaining.isEmpty) {
          emit(
            CaptureSuccess(
              message: _createdMessage(accepted),
              createdCount: accepted,
            ),
          );
        } else {
          emit(
            current.copyWith(
              item: current.item.copyWith(status: InboxStatus.processed),
              drafts: remaining,
              acceptedCount: accepted,
              accepting: false,
            ),
          );
        }
      },
    );
  }

  Future<void> _onAcceptAllRequested(
    CaptureAcceptAllRequested event,
    Emitter<CaptureState> emit,
  ) async {
    final current = state;
    if (current is! CaptureDraftsReview || current.accepting) return;
    emit(current.copyWith(accepting: true));

    var item = current.item;
    var accepted = current.acceptedCount;
    final remaining = List<ZettelDraft>.of(current.drafts);
    while (remaining.isNotEmpty) {
      final result = await _acceptDraft(
        AcceptDraftParams(draft: remaining.first, item: item),
      );
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      if (failure != null) {
        // Keep the drafts that were not created yet so the user can retry.
        emit(
          CaptureDraftsReview(
            item: item,
            drafts: remaining,
            acceptedCount: accepted,
            errorMessage: _acceptFailedMessage(failure),
          ),
        );
        return;
      }
      remaining.removeAt(0);
      accepted += 1;
      item = item.copyWith(status: InboxStatus.processed);
    }
    emit(
      CaptureSuccess(
        message: _createdMessage(accepted),
        createdCount: accepted,
      ),
    );
  }

  void _onDraftsRejected(
    CaptureDraftsRejected event,
    Emitter<CaptureState> emit,
  ) {
    if (state is! CaptureDraftsReview) return;
    emit(
      const CaptureSuccess(
        message:
            'Brouillons rejetés. La capture reste dans l’inbox pour un '
            'traitement ultérieur.',
      ),
    );
  }

  Future<void> _onReset(CaptureReset event, Emitter<CaptureState> emit) async {
    await _cancelDictation();
    emit(const CaptureIdle());
  }

  Future<void> _cancelDictation() async {
    if (_dictationSub == null) return;
    await _dictationSub?.cancel();
    _dictationSub = null;
    await _stopDictation(const NoParams());
  }

  static String _createdMessage(int count) => count > 1
      ? '$count notes créées dans le vault.'
      : '1 note créée dans le vault.';

  static String _acceptFailedMessage(Failure failure) =>
      'La création de la note a échoué (${failure.message}). '
      'Les brouillons restants sont conservés : vous pouvez réessayer.';

  @override
  Future<void> close() async {
    await _cancelDictation();
    return super.close();
  }
}
