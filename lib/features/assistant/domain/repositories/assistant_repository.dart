import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/assistant_answer.dart';
import '../entities/zettel_draft.dart';

/// High-level AI operations over the zettelkasten.
///
/// Implementations combine the vault index (retrieval) and the
/// [LocalAiService] (generation).
abstract interface class AssistantRepository {
  /// True when the local model is installed and usable.
  Future<Either<Failure, bool>> isReady();

  /// Installs the on-device model, emitting progress 0.0 → 1.0.
  Stream<Either<Failure, double>> installModel();

  /// Splits raw captured text into clean atomic zettel drafts with
  /// titles, tags and suggested links to existing related zettels.
  Future<Either<Failure, List<ZettelDraft>>> proposeDrafts({
    required String rawText,
    String? sourceInboxItemId,
  });

  /// Answers a natural-language question using the vault as context
  /// (local RAG), citing the zettels used.
  Future<Either<Failure, AssistantAnswer>> answerQuestion(String question);
}
