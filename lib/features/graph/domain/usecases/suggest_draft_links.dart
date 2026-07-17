import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
// Cross-feature dependency — documented exception: the assistant feature owns
// the local RAG index (semantic search with keyword fallback); the graph
// reuses it for its suggestion use cases instead of shipping a second
// similarity engine.
import '../../../assistant/data/datasources/vault_rag_index.dart';
import '../../../zettel/domain/entities/zettel.dart';
import '../../../zettel/domain/repositories/zettel_repository.dart';
import '../entities/related_note_suggestion.dart';

class SuggestDraftLinksParams extends Equatable {
  const SuggestDraftLinksParams({
    required this.text,
    this.excludedIds = const {},
    this.count = 5,
  });

  /// Free text the suggestions are searched around (a draft being typed,
  /// or `title\nbody` of an existing note).
  final String text;

  /// Ids never suggested: the note itself and its already-linked neighbors.
  final Set<String> excludedIds;

  /// Maximum number of suggestions returned.
  final int count;

  @override
  List<Object?> get props => [text, excludedIds, count];
}

/// Top-K notes semantically close to a free text but not in [
/// SuggestDraftLinksParams.excludedIds] — powers the editor's « fleur »
/// banner and, through [SuggestRelatedNotes], every Pollinisation surface.
///
/// Backed by the local RAG index: results may be empty (no embedding model
/// and no keyword match) and the first call may be slow (lazy indexing).
/// Suggestions pointing at notes deleted since they were indexed are
/// silently dropped while their titles are resolved.
@injectable
class SuggestDraftLinks
    implements UseCase<List<RelatedNoteSuggestion>, SuggestDraftLinksParams> {
  const SuggestDraftLinks(this._repository, this._ragIndex);

  final ZettelRepository _repository;
  final VaultRagIndex _ragIndex;

  @override
  Future<Either<Failure, List<RelatedNoteSuggestion>>> call(
    SuggestDraftLinksParams params,
  ) async {
    if (params.text.trim().isEmpty || params.count <= 0) {
      return const Right([]);
    }
    // Over-fetch so that filtering the excluded ids out still leaves up to
    // [params.count] suggestions.
    final hits = await _ragIndex.topKScored(
      params.text,
      k: params.count + params.excludedIds.length + 1,
    );
    final suggestions = <RelatedNoteSuggestion>[];
    for (final (id, _, score) in hits) {
      if (params.excludedIds.contains(id.value)) continue;
      // Resolve the live title; a stale hit (note deleted) is dropped.
      final zettel = (await _repository.getZettelById(
        id,
      )).fold<Zettel?>((_) => null, (found) => found);
      if (zettel == null) continue;
      suggestions.add(
        RelatedNoteSuggestion(id: id.value, title: zettel.title, score: score),
      );
      if (suggestions.length >= params.count) break;
    }
    return Right(suggestions);
  }
}
