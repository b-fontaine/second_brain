import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/inbox_item.dart';
import '../entities/zettel.dart';
import '../repositories/inbox_repository.dart';
import 'create_zettel.dart';

/// « Repiquer » : turns a pending [InboxItem] of the nursery (« Pépinière »)
/// into a permanent zettel, then marks the item processed so it leaves the
/// pending queue.
///
/// The created note keeps the capture provenance ([InboxItem.captureSource])
/// and defaults to the enriched proposal ([InboxItem.proposedTitle], raw
/// text, parcelles); [TransplantSeedlingParams.title]/`body`/`tags` override
/// those defaults when the draft was edited before transplanting.
///
/// Same contract as the assistant's draft acceptance (`AcceptDraft`): the
/// status update is best effort — once the zettel exists, a failed inbox
/// write must not surface as a failed transplant (the item simply stays
/// pending and can be composted manually).
@injectable
class TransplantSeedling implements UseCase<Zettel, TransplantSeedlingParams> {
  const TransplantSeedling(this._createZettel, this._inboxRepository);

  final CreateZettel _createZettel;
  final InboxRepository _inboxRepository;

  @override
  Future<Either<Failure, Zettel>> call(TransplantSeedlingParams params) async {
    final item = params.item;
    final overriddenTitle = params.title?.trim();
    final created = await _createZettel(
      CreateZettelParams(
        // A blank override falls back to the proposal: transplanting never
        // fails on the title (the proposal itself is never empty).
        title: (overriddenTitle == null || overriddenTitle.isEmpty)
            ? item.proposedTitle
            : overriddenTitle,
        body: params.body ?? item.rawText,
        tags: params.tags ?? item.tags,
        source: item.captureSource,
      ),
    );
    return created.fold<Future<Either<Failure, Zettel>>>(
      (failure) async => Left(failure),
      (zettel) async {
        if (item.status != InboxStatus.processed) {
          await _inboxRepository.updateItem(
            item.copyWith(status: InboxStatus.processed),
          );
        }
        return Right(zettel);
      },
    );
  }
}

class TransplantSeedlingParams extends Equatable {
  const TransplantSeedlingParams({
    required this.item,
    this.title,
    this.body,
    this.tags,
  });

  /// The pending capture to transplant.
  final InboxItem item;

  /// Edited title; null (or blank) keeps [InboxItem.proposedTitle].
  final String? title;

  /// Edited body; null keeps [InboxItem.rawText].
  final String? body;

  /// Edited parcelles; null keeps [InboxItem.tags].
  final List<String>? tags;

  @override
  List<Object?> get props => [item, title, body, tags];
}
