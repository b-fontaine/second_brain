import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/serre_tokens.dart';
import '../bloc/models_install_cubit.dart';

/// Models screen content: per-model install status and download progress
/// (voice STT bundle + assistant LLM), shared by the last onboarding step
/// (`SetupPage`, with header and leave actions) and by « Réglages →
/// Modèles » (`ModelsPage`, cards only).
///
/// The backing [ModelsInstallCubit] is an app-lifetime singleton and is
/// NEVER closed here: « Continuer en arrière-plan » leaves the screen while
/// the downloads keep streaming.
class ModelsInstallView extends StatefulWidget {
  const ModelsInstallView({
    super.key,
    this.cubit,
    this.showSetupActions = false,
    this.onLeave,
  });

  /// Test seam: injected cubit; resolved through getIt otherwise.
  final ModelsInstallCubit? cubit;

  /// Onboarding context: shows the « coffre prêt » header and the
  /// « Plus tard » / « Continuer en arrière-plan » actions.
  final bool showSetupActions;

  /// Invoked by the leave actions; defaults to `context.go('/')`.
  final VoidCallback? onLeave;

  @override
  State<ModelsInstallView> createState() => _ModelsInstallViewState();
}

class _ModelsInstallViewState extends State<ModelsInstallView> {
  late final ModelsInstallCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = widget.cubit ?? getIt<ModelsInstallCubit>();
    // Refresh the installed/not-installed statuses; init() never clobbers
    // a download already running in the background.
    _cubit.init();
  }

  void _leave() {
    final onLeave = widget.onLeave;
    if (onLeave != null) {
      onLeave();
    } else {
      context.go(AppRoutes.explorer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<ModelsInstallCubit, ModelsInstallState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showSetupActions) ...[
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
                  'Modèles locaux (optionnels)',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'La dictée vocale et l’assistant fonctionnent entièrement '
                  'hors ligne grâce à des modèles téléchargés une seule fois '
                  'sur cet appareil. Vous pourrez aussi les installer plus '
                  'tard depuis les réglages.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
              _ModelCard(
                key: const Key('voice-model-card'),
                icon: Icons.record_voice_over_outlined,
                title: 'Reconnaissance vocale',
                subtitle:
                    'Dictée française et transcription audio — '
                    '≈ 190 Mo (mobile) à 385 Mo (ordinateur)',
                info: state.voice,
                downloadKey: const Key('voice-model-download'),
                progressKey: const Key('voice-model-progress'),
                onDownload: () =>
                    context.read<ModelsInstallCubit>().downloadVoice(),
              ),
              const SizedBox(height: 12),
              _ModelCard(
                key: const Key('assistant-model-card'),
                icon: Icons.psychology_outlined,
                title: 'Assistant local',
                subtitle:
                    'Organisation des captures et réponses de l’assistant — '
                    '≈ 600 Mo',
                info: state.assistant,
                downloadKey: const Key('assistant-model-download'),
                progressKey: const Key('assistant-model-progress'),
                onDownload: () =>
                    context.read<ModelsInstallCubit>().downloadAssistant(),
              ),
              if (widget.showSetupActions) ...[
                const SizedBox(height: 24),
                _buildLeaveAction(state),
              ],
            ],
          );
        },
      ),
    );
  }

  /// « Plus tard » before anything started, « Continuer en arrière-plan »
  /// while a download runs (it keeps running after leaving), « Continuer »
  /// once every model settled.
  Widget _buildLeaveAction(ModelsInstallState state) {
    if (state.anyDownloading) {
      return FilledButton(
        key: const Key('models_continue_button'),
        onPressed: _leave,
        child: const Text('Continuer en arrière-plan'),
      );
    }
    if (state.allSettled) {
      return FilledButton(
        key: const Key('models_continue_button'),
        onPressed: _leave,
        child: const Text('Continuer'),
      );
    }
    return TextButton(
      key: const Key('skip_model_button'),
      onPressed: _leave,
      child: const Text('Plus tard'),
    );
  }
}

/// One model bundle card: identity row, then the phase-specific footer
/// (static label, determinate progress bar, install confirmation, error
/// with retry, or unsupported notice). Never shows an indeterminate
/// indicator.
class _ModelCard extends StatelessWidget {
  const _ModelCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.info,
    required this.downloadKey,
    required this.progressKey,
    required this.onDownload,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ModelInstallInfo info;
  final Key downloadKey;
  final Key progressKey;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: tokens.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.sub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildStatus(theme, tokens),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatus(ThemeData theme, SerreTokens tokens) {
    switch (info.phase) {
      case ModelInstallPhase.checking:
        return [
          Text(
            'Vérification…',
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.sub),
          ),
        ];
      case ModelInstallPhase.notInstalled:
        return [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              key: downloadKey,
              onPressed: onDownload,
              child: const Text('Télécharger'),
            ),
          ),
        ];
      case ModelInstallPhase.downloading:
        final percent = (info.progress.clamp(0.0, 1.0) * 100).round();
        return [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  key: progressKey,
                  // Determinate on purpose: an indeterminate bar would
                  // animate forever (pumpAndSettle must terminate).
                  value: info.progress.clamp(0.0, 1.0),
                ),
              ),
              const SizedBox(width: 12),
              Text('$percent %', style: theme.textTheme.labelMedium),
            ],
          ),
        ];
      case ModelInstallPhase.ready:
        return [
          Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: tokens.accent),
              const SizedBox(width: 8),
              Text(
                'Installé',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.accent,
                ),
              ),
            ],
          ),
        ];
      case ModelInstallPhase.failed:
        return [
          Text(
            info.message ?? ModelsInstallCubit.downloadFailedMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              key: downloadKey,
              onPressed: onDownload,
              child: const Text('Réessayer'),
            ),
          ),
        ];
      case ModelInstallPhase.unsupported:
        return [
          Text(
            info.message ?? ModelsInstallCubit.assistantUnsupportedMessage,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.sub),
          ),
        ];
    }
  }
}
