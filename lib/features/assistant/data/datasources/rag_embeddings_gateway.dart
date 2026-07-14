import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:injectable/injectable.dart';

/// A document retrieved by semantic similarity search.
typedef SemanticHit = ({String id, String content, double similarity});

/// Thin seam over the flutter_gemma embeddings + vector store stack so that
/// [VaultRagIndex] can be unit-tested and can degrade to keyword search when
/// no embedding model is installed.
abstract interface class RagEmbeddingsGateway {
  /// True when an embedding model is installed and the vector store is usable.
  Future<bool> isAvailable();

  /// Adds or replaces a document in the vector store (embeds automatically).
  Future<void> upsertDocument({required String id, required String content});

  /// Removes every document from the vector store. The flutter_gemma plugin
  /// API exposes no per-document delete, so eviction is clear + re-upsert.
  Future<void> clear();

  /// Returns the [topK] most similar documents, best first.
  Future<List<SemanticHit>> search(String query, int topK);
}

/// flutter_gemma_embeddings + flutter_gemma_rag_sqlite implementation.
///
/// Requires `FlutterGemma.initialize(embeddingBackends: [...], vectorStore:
/// SqliteVectorStore())` in `main()` and an installed embedder — see
/// [installGeckoEmbedder]. When either is missing, [isAvailable] returns
/// false and [VaultRagIndex] falls back to keyword scoring.
@LazySingleton(as: RagEmbeddingsGateway)
class GemmaRagEmbeddingsGateway implements RagEmbeddingsGateway {
  GemmaRagEmbeddingsGateway();

  /// Gecko 110m — public HF repo (no token), 256-token quantized variant.
  static const String geckoModelUrl =
      'https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/'
      'Gecko_256_quant.tflite';

  static const String geckoTokenizerUrl =
      'https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/'
      'sentencepiece.model';

  /// Name of the sqlite vector store database.
  static const String vectorStoreName = 'vault_rag_index';

  bool _storeInitialized = false;

  /// Downloads and activates the public Gecko embedding model (~110 MB).
  ///
  /// Optional: to be called by the setup flow once the LLM itself is
  /// installed. RAG works in keyword mode until then.
  Future<void> installGeckoEmbedder({
    void Function(int percent)? onProgress,
  }) async {
    final builder = FlutterGemma.installEmbedder()
        .modelFromNetwork(geckoModelUrl)
        .tokenizerFromNetwork(geckoTokenizerUrl);
    if (onProgress != null) {
      builder.withModelProgress(onProgress);
    }
    await builder.install();
  }

  @override
  Future<bool> isAvailable() async {
    try {
      if (!FlutterGemma.hasActiveEmbedder()) return false;
      await _ensureStore();
      return true;
    } catch (_) {
      // Unconfigured vector store / uninitialized registry → keyword mode.
      return false;
    }
  }

  @override
  Future<void> upsertDocument({
    required String id,
    required String content,
  }) async {
    await _ensureStore();
    await FlutterGemmaPlugin.instance.addDocument(id: id, content: content);
  }

  @override
  Future<void> clear() async {
    await _ensureStore();
    await FlutterGemmaPlugin.instance.clearVectorStore();
  }

  @override
  Future<List<SemanticHit>> search(String query, int topK) async {
    await _ensureStore();
    final results = await FlutterGemmaPlugin.instance.searchSimilar(
      query: query,
      topK: topK,
    );
    return [
      for (final result in results)
        (id: result.id, content: result.content, similarity: result.similarity),
    ];
  }

  Future<void> _ensureStore() async {
    if (_storeInitialized) return;
    await FlutterGemmaPlugin.instance.initializeVectorStore(vectorStoreName);
    _storeInitialized = true;
  }
}
