import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
// Cross-feature dependency — documented exception: the assistant feature owns
// the local RAG index (semantic search with keyword fallback); the graph
// reuses it to flag « fleur » suggestions instead of shipping a second
// similarity engine.
import '../../../assistant/data/datasources/vault_rag_index.dart';
import '../../../zettel/domain/entities/zettel_id.dart';
import '../../../zettel/domain/repositories/zettel_repository.dart';

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
/// the « fleurs » of the constellation.
///
/// Backed by the local RAG index: results may be empty (no embedding model
/// and no keyword match) and the first call may be slow (lazy indexing).
@injectable
class SuggestRelatedNotes
    implements UseCase<List<String>, SuggestRelatedNotesParams> {
  const SuggestRelatedNotes(this._repository, this._ragIndex);

  final ZettelRepository _repository;
  final VaultRagIndex _ragIndex;

  @override
  Future<Either<Failure, List<String>>> call(
    SuggestRelatedNotesParams params,
  ) async {
    final zettelResult = await _repository.getZettelById(
      ZettelId.fromString(params.zettelId),
    );
    return zettelResult.fold<Future<Either<Failure, List<String>>>>(
      (failure) async => Left(failure),
      (zettel) async {
        // Over-fetch so that filtering out the note itself and its linked
        // neighbors still leaves up to [params.count] suggestions.
        final hits = await _ragIndex.topK(
          '${zettel.title}\n${zettel.body}',
          k: params.count + params.excludedIds.length + 1,
        );
        final ids = <String>[];
        for (final (id, _) in hits) {
          final value = id.value;
          if (value == params.zettelId || params.excludedIds.contains(value)) {
            continue;
          }
          ids.add(value);
          if (ids.length >= params.count) break;
        }
        return Right(ids);
      },
    );
  }
}
