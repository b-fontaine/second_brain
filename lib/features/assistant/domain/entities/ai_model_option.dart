import 'package:equatable/equatable.dart';

/// Identifier of an on-device LLM the user can pick for the assistant.
///
/// Kept free of any flutter_gemma type so the domain layer stays
/// independent of the inference engine; the data layer maps each id to a
/// concrete model URL/type (see `GemmaModelCatalog`).
enum AiModelId { qwen3, gemma4E2B, gemma4E4B }

/// User-facing description of an [AiModelId], used by the model-choice
/// screen (onboarding) and the settings screen.
class AiModelOption extends Equatable {
  const AiModelOption({
    required this.id,
    required this.label,
    required this.sizeLabel,
    required this.description,
    required this.constraints,
    this.recommended = false,
  });

  final AiModelId id;
  final String label;

  /// Approximate download size, e.g. "≈ 586 Mo".
  final String sizeLabel;
  final String description;

  /// Short bullet points: hardware/platform constraints, capabilities.
  final List<String> constraints;

  final bool recommended;

  @override
  List<Object?> get props => [
    id,
    label,
    sizeLabel,
    description,
    constraints,
    recommended,
  ];
}

/// The three on-device models offered to the user.
abstract final class AiModelCatalog {
  const AiModelCatalog._();

  static const qwen3 = AiModelOption(
    id: AiModelId.qwen3,
    label: 'Qwen3 0.6B',
    sizeLabel: '≈ 586 Mo',
    description:
        'Modèle léger et rapide, texte uniquement. Bon choix par défaut '
        'sur tous les appareils, y compris les plus anciens.',
    constraints: [
      'Aucun jeton Hugging Face requis',
      'Pas de compréhension d\'image ni d\'audio',
      'Qualité en français correcte mais limitée',
    ],
    recommended: true,
  );

  static const gemma4E2B = AiModelOption(
    id: AiModelId.gemma4E2B,
    label: 'Gemma 4 E2B',
    sizeLabel: '≈ 2,6 Go',
    description:
        'Modèle multimodal (texte, image, audio) de Google avec appel de '
        'fonctions et mode de raisonnement. Meilleure qualité, notamment '
        'en français.',
    constraints: [
      'Aucun jeton Hugging Face requis',
      'Recommandé avec au moins 6 Go de RAM disponible',
      'Sur Linux, l\'accélération GPU nécessite un pilote Vulkan du '
          'fabricant (le rendu logiciel Mesa est insuffisant)',
    ],
  );

  static const gemma4E4B = AiModelOption(
    id: AiModelId.gemma4E4B,
    label: 'Gemma 4 E4B',
    sizeLabel: '≈ 3,7 Go',
    description:
        'Version plus grande de Gemma 4 : même capacités multimodales, '
        'qualité encore meilleure, mais plus lente et plus gourmande.',
    constraints: [
      'Aucun jeton Hugging Face requis',
      'Recommandé avec au moins 8 Go de RAM disponible',
      'Sur Linux, l\'accélération GPU nécessite un pilote Vulkan du '
          'fabricant (le rendu logiciel Mesa est insuffisant)',
    ],
  );

  static const List<AiModelOption> options = [qwen3, gemma4E2B, gemma4E4B];

  static AiModelOption optionFor(AiModelId id) =>
      options.firstWhere((option) => option.id == id);
}
