import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Optional last onboarding step: offer to download the local AI model.
/// The download itself lives in the assistant feature (`/chat`).
class ModelDownloadStep extends StatelessWidget {
  const ModelDownloadStep({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Votre coffre est prêt',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Assistant IA local (optionnel)',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Second Brain peut utiliser un modèle d'IA exécuté entièrement sur "
          'votre appareil pour organiser vos captures et répondre à vos '
          'questions. Le téléchargement (~600 Mo) est optionnel et reste '
          'possible plus tard depuis le chat.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton(
          key: const Key('download_model_button'),
          // Honest label: this navigates to the assistant, where the
          // download itself is started from the model status banner.
          onPressed: () => context.go('/chat'),
          child: const Text('Configurer dans l’assistant…'),
        ),
        const SizedBox(height: 12),
        TextButton(
          key: const Key('skip_model_button'),
          onPressed: () => context.go('/'),
          child: const Text('Plus tard'),
        ),
      ],
    );
  }
}
