import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../assistant/domain/entities/zettel_draft.dart';
import '../../../zettel/domain/entities/inbox_item.dart';
import '../../../zettel/domain/entities/zettel.dart';
import '../../../zettel/domain/repositories/inbox_repository.dart';
import '../../../zettel/domain/usecases/create_zettel.dart';

/// Turns an accepted [ZettelDraft] into a permanent zettel with provenance
/// `capture:<type>:<ref>` and marks the originating [InboxItem] processed.
@injectable
class AcceptDraft implements UseCase<Zettel, AcceptDraftParams> {
  const AcceptDraft(this._createZettel, this._inboxRepository);

  final CreateZettel _createZettel;
  final InboxRepository _inboxRepository;

  @override
  Future<Either<Failure, Zettel>> call(AcceptDraftParams params) async {
    final created = await _createZettel(
      CreateZettelParams(
        title: params.draft.title,
        body: _bodyWithSuggestedLinks(params.draft),
        tags: params.draft.tags,
        source: params.item.captureSource,
      ),
    );
    return created.fold<Future<Either<Failure, Zettel>>>(
      (failure) async => Left(failure),
      (zettel) async {
        if (params.item.status != InboxStatus.processed) {
          // Best effort: the zettel exists, a failed status update must not
          // surface as a failed acceptance (the item simply stays pending).
          await _inboxRepository.updateItem(
            params.item.copyWith(status: InboxStatus.processed),
          );
        }
        return Right(zettel);
      },
    );
  }

  /// Appends the suggested links that the draft body does not already
  /// contain, so accepted notes keep their connections.
  String _bodyWithSuggestedLinks(ZettelDraft draft) {
    final body = draft.body.trimRight();
    final missing = draft.suggestedLinks
        .where((id) => !body.contains('[[${id.value}'))
        .toList();
    if (missing.isEmpty) return body;
    final links = missing.map((id) => '[[${id.value}]]').join(', ');
    return '$body\n\nVoir aussi : $links';
  }
}

class AcceptDraftParams extends Equatable {
  const AcceptDraftParams({required this.draft, required this.item});

  final ZettelDraft draft;

  /// The inbox item the draft was derived from.
  final InboxItem item;

  @override
  List<Object?> get props => [draft, item];
}
