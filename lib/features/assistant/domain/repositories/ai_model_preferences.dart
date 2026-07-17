import '../entities/ai_model_option.dart';

/// Persists which on-device model the user selected, across restarts.
///
/// Null means the user never made a choice yet (first run): callers fall
/// back to [AiModelCatalog.qwen3].
abstract interface class AiModelPreferences {
  Future<AiModelId?> getSelectedModel();

  Future<void> setSelectedModel(AiModelId modelId);
}
