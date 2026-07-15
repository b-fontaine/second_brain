import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../assistant/domain/entities/ai_model_option.dart';
import '../../../assistant/presentation/bloc/model_status_cubit.dart';
import '../../../assistant/presentation/bloc/model_status_state.dart';

/// Last onboarding step: choose which on-device AI model to install, or
/// skip entirely. The choice can always be changed later from Paramètres.
class ModelChoiceStep extends StatelessWidget {
  const ModelChoiceStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ModelStatusCubit>()..check(),
      child: const _ModelChoiceView(),
    );
  }
}

class _ModelChoiceView extends StatelessWidget {
  const _ModelChoiceView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ModelStatusCubit, ModelStatusState>(
      builder: (context, state) {
        final isBusy =
            state is ModelStatusDownloading || state is ModelStatusChecking;
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
            const SizedBox(height: 24),
            ..._body(context, state, isBusy: isBusy),
          ],
        );
      },
    );
  }

  List<Widget> _body(
    BuildContext context,
    ModelStatusState state, {
    required bool isBusy,
  }) {
    final theme = Theme.of(context);

    if (state is ModelStatusUnsupported) {
      return [
        Text(
          state.message,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('skip_model_button'),
          onPressed: () => context.go('/'),
          child: const Text('Continuer'),
        ),
      ];
    }

    if (state is ModelStatusReady) {
      return [
        Text(
          'Modèle installé, l\'assistant est prêt à répondre à vos '
          'questions hors ligne.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('continue_button'),
          onPressed: () => context.go('/'),
          child: const Text('Continuer'),
        ),
      ];
    }

    return [
      Text(
        "Second Brain peut utiliser un modèle d'IA exécuté entièrement sur "
        'votre appareil pour organiser vos captures et répondre à vos '
        'questions. Choisissez un modèle ci-dessous ou faites-le plus tard '
        'depuis les paramètres.',
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      for (final option in AiModelCatalog.options) ...[
        _ModelCard(option: option, enabled: !isBusy),
        const SizedBox(height: 12),
      ],
      if (state is ModelStatusDownloading) ...[
        const SizedBox(height: 8),
        _DownloadProgress(progress: state.progress),
      ],
      if (state is ModelStatusError) ...[
        const SizedBox(height: 8),
        Text(
          state.message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
      ],
      const SizedBox(height: 12),
      TextButton(
        key: const Key('skip_model_button'),
        onPressed: isBusy ? null : () => context.go('/'),
        child: const Text('Plus tard'),
      ),
    ];
  }
}

/// One selectable model: label, size, description and technical
/// constraints, with a button that triggers download + install.
class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.option, required this.enabled});

  final AiModelOption option;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (option.recommended)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: const Text('Recommandé'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    option.sizeLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(option.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (final constraint in option.constraints)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $constraint',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                key: Key('select_model_${option.id.name}'),
                onPressed: enabled
                    ? () => context
                          .read<ModelStatusCubit>()
                          .selectAndDownload(option.id)
                    : null,
                child: const Text('Télécharger et utiliser'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress});

  /// 0.0 → 1.0
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = progress.clamp(0.0, 1.0).toDouble();
    final percent = (fraction * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Téléchargement du modèle… $percent %',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: fraction),
      ],
    );
  }
}
