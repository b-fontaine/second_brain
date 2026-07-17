import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../zettel/domain/entities/zettel_id.dart';
import '../../../zettel/domain/repositories/zettel_repository.dart';
import '../entities/related_note_suggestion.dart';
import 'suggest_draft_links.dart';

class SuggestRelatedNotesParams extends Equatable {
  const SuggestRelatedNotesParams({
    required this.zettelId,
    this.excludedIds = const {},
    this.count = 5,
  });

  /// Note around which suggestions are searched.
  final String zettelId;

  /// Ids never suggested: the note itself and its already-linked neighbors.
  final Set<String> excludedIds;

  /// Maximum number of suggestions returned.
  final int count;

  @override
  List<Object?> get props => [zettelId, excludedIds, count];
}

/// Top-K notes semantically close to a given note but not linked to it —
/// the « fleurs » of the constellation and the Pollinisation section of the
/// reading view. Suggestions carry the resolved title and, when the semantic
/// index answered, a normalized score (see [RelatedNoteSuggestion]).
///
/// Thin adapter over [SuggestDraftLinks]: loads the note, then searches
/// around its `title\nbody` with the note itself always excluded.
@injectable
class SuggestRelatedNotes
    implements
        UseCase<List<RelatedNoteSuggestion>, SuggestRelatedNotesParams> {
  const SuggestRelatedNotes(this._repository, this._suggestDraftLinks);

  final ZettelRepository _repository;
  final SuggestDraftLinks _suggestDraftLinks;

  @override
  Future<Either<Failure, List<RelatedNoteSuggestion>>> call(
    SuggestRelatedNotesParams params,
  ) async {
    final zettelResult = await _repository.getZettelById(
      ZettelId.fromString(params.zettelId),
    );
    return zettelResult
        .fold<Future<Either<Failure, List<RelatedNoteSuggestion>>>>(
          (failure) async => Left(failure),
          (zettel) => _suggestDraftLinks(
            SuggestDraftLinksParams(
              text: '${zettel.title}\n${zettel.body}',
              excludedIds: {params.zettelId, ...params.excludedIds},
              count: params.count,
            ),
          ),
        );
  }
}
