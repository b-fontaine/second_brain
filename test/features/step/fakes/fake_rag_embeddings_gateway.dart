import 'package:second_brain/features/assistant/data/datasources/rag_embeddings_gateway.dart';

/// Embeddings gateway that reports "no embedding model installed", which
/// forces the real `VaultRagIndex` into its always-available keyword
/// (term-frequency) mode — full retrieval coverage without native code.
class FakeRagEmbeddingsGateway implements RagEmbeddingsGateway {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> upsertDocument({
    required String id,
    required String content,
  }) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<List<SemanticHit>> search(String query, int topK) async => const [];
}
