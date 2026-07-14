import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/model_status_cubit.dart';
import '../bloc/model_status_state.dart';

/// Banner above the chat reflecting the on-device model lifecycle:
/// install invitation, download progress, unsupported platform or error.
class ModelStatusBanner extends StatelessWidget {
  const ModelStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModelStatusCubit, ModelStatusState>(
      builder: (context, state) {
        return switch (state) {
          ModelStatusChecking() => const LinearProgressIndicator(minHeight: 2),
          ModelStatusReady() => const SizedBox.shrink(),
          ModelStatusNotInstalled() => _BannerCard(
            icon: Icons.download_for_offline_outlined,
            text:
                'L’assistant a besoin d’un modèle d’IA local pour '
                'répondre à vos questions hors ligne.',
            action: FilledButton.tonalIcon(
              onPressed: () => context.read<ModelStatusCubit>().download(),
              icon: const Icon(Icons.download),
              label: const Text('Télécharger le modèle (≈600 Mo)'),
            ),
          ),
          ModelStatusDownloading(:final progress) => _DownloadCard(
            progress: progress,
          ),
          ModelStatusUnsupported(:final message) => _BannerCard(
            icon: Icons.desktop_access_disabled_outlined,
            text: message,
          ),
          ModelStatusError(:final message) => _BannerCard(
            icon: Icons.error_outline,
            text: message,
            isError: true,
            action: TextButton(
              onPressed: () => context.read<ModelStatusCubit>().check(),
              child: const Text('Réessayer'),
            ),
          ),
        };
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.icon,
    required this.text,
    this.action,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final Widget? action;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Material(
      color: isError ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: TextStyle(color: foreground)),
                ),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: action),
            ],
          ],
        ),
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.progress});

  /// 0.0 → 1.0
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = progress.clamp(0.0, 1.0).toDouble();
    final percent = (fraction * 100).round();
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Téléchargement du modèle… $percent %',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: fraction),
          ],
        ),
      ),
    );
  }
}
