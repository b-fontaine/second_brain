import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/ai_model_option.dart';
import '../../domain/repositories/ai_model_preferences.dart';

@LazySingleton(as: AiModelPreferences)
class AiModelPreferencesImpl implements AiModelPreferences {
  static const _selectedModelKey = 'selected_ai_model';

  @override
  Future<AiModelId?> getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_selectedModelKey);
    if (name == null) return null;
    return AiModelId.values.asNameMap()[name];
  }

  @override
  Future<void> setSelectedModel(AiModelId modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, modelId.name);
  }
}
