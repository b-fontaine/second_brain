/// Progress of the on-device model installation.
class ModelDownloadProgress {
  const ModelDownloadProgress(this.fraction);

  /// 0.0 → 1.0
  final double fraction;
}

/// Abstraction over the on-device LLM (flutter_gemma or a desktop
/// fallback). Selected per platform in the DI layer.
///
/// Throws [AiException] on inference errors; never returns Failures —
/// this is a data-layer-facing service consumed by repositories.
abstract interface class LocalAiService {
  /// True when a model is installed and ready for inference.
  Future<bool> isModelReady();

  /// Downloads and installs the model. Emits progress until completion.
  Stream<ModelDownloadProgress> installModel();

  /// One-shot completion.
  Future<String> generate(String prompt, {String? systemPrompt});

  /// Token-streamed completion.
  Stream<String> generateStream(String prompt, {String? systemPrompt});

  /// Frees native resources (sessions, model memory).
  Future<void> dispose();
}
