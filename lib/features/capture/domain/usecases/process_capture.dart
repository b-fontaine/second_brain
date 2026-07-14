import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/clock.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../assistant/domain/entities/zettel_draft.dart';
import '../../../assistant/domain/repositories/assistant_repository.dart';
import '../../../zettel/domain/entities/inbox_item.dart';
import '../../../zettel/domain/entities/zettel_id.dart';
import '../../../zettel/domain/repositories/inbox_repository.dart';

/// Persists a capture as an [InboxItem] (nothing is ever lost) and, unless
/// [ProcessCaptureParams.proposeDrafts] is false, asks the local assistant
/// to split it into atomic zettel drafts.
///
/// Fails with an [AiFailure] — without writing anything — when drafts are
/// requested but the local model is not installed, so the UI can offer to
/// save the capture to the inbox as-is instead.
@injectable
class ProcessCapture
    implements UseCase<ProcessCaptureResult, ProcessCaptureParams> {
  const ProcessCapture(
    this._inboxRepository,
    this._assistantRepository,
    this._clock,
  );

  final InboxRepository _inboxRepository;
  final AssistantRepository _assistantRepository;
  final Clock _clock;

  @override
  Future<Either<Failure, ProcessCaptureResult>> call(
    ProcessCaptureParams params,
  ) async {
    final rawText = params.rawText.trim();
    if (rawText.isEmpty) {
      return const Left(ValidationFailure('Aucun texte à capturer'));
    }

    if (params.proposeDrafts) {
      final readiness = await _assistantRepository.isReady();
      final isReady = readiness.getOrElse((_) => false);
      if (!isReady) {
        return const Left(AiFailure("Le modèle d'IA local n'est pas installé"));
      }
    }

    final now = _clock.now();
    final item = InboxItem(
      id: ZettelId.fromDateTime(now).value,
      type: params.type,
      rawText: rawText,
      capturedAt: now,
      assetPath: params.assetPath,
    );
    final saved = await _inboxRepository.addItem(item);

    return saved.fold<Future<Either<Failure, ProcessCaptureResult>>>(
      (failure) async => Left(failure),
      (savedItem) async {
        if (!params.proposeDrafts) {
          return Right(ProcessCaptureResult(item: savedItem));
        }
        final drafts = await _assistantRepository.proposeDrafts(
          rawText: rawText,
          sourceInboxItemId: savedItem.id,
        );
        return drafts.fold(
          // The item is already safe in the inbox: report success with an
          // explanatory message rather than losing that information.
          (failure) => Right(
            ProcessCaptureResult(
              item: savedItem,
              assistantMessage:
                  "L'assistant n'a pas pu proposer de notes "
                  '(${failure.message}). La capture est conservée dans '
                  "l'inbox.",
            ),
          ),
          (proposed) => proposed.isEmpty
              ? Right(
                  ProcessCaptureResult(
                    item: savedItem,
                    assistantMessage:
                        "L'assistant n'a proposé aucune note. La capture est "
                        "conservée dans l'inbox.",
                  ),
                )
              : Right(ProcessCaptureResult(item: savedItem, drafts: proposed)),
        );
      },
    );
  }
}

class ProcessCaptureParams extends Equatable {
  const ProcessCaptureParams({
    required this.rawText,
    required this.type,
    this.assetPath,
    this.proposeDrafts = true,
  });

  final String rawText;
  final CaptureType type;

  /// Relative vault path of the original asset (audio file, image).
  final String? assetPath;

  /// When false, only persists the inbox item (used when the local AI model
  /// is unavailable).
  final bool proposeDrafts;

  @override
  List<Object?> get props => [rawText, type, assetPath, proposeDrafts];
}

class ProcessCaptureResult extends Equatable {
  const ProcessCaptureResult({
    required this.item,
    this.drafts = const [],
    this.assistantMessage,
  });

  /// The persisted inbox item.
  final InboxItem item;

  /// Drafts proposed by the assistant; empty in inbox-only mode.
  final List<ZettelDraft> drafts;

  /// Set when the item was saved but the assistant could not propose drafts.
  final String? assistantMessage;

  @override
  List<Object?> get props => [item, drafts, assistantMessage];
}
