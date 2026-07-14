import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/capture_bloc.dart';

/// Shown when the local AI model is missing: offer to keep the capture
/// as a raw inbox item instead of losing it.
class AssistantUnavailableView extends StatelessWidget {
  const AssistantUnavailableView({super.key, required this.state});

  final CaptureAssistantUnavailable state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<CaptureBloc>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'L’assistant IA n’est pas disponible',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${state.message}. Vous pouvez enregistrer la capture telle '
                'quelle dans l’inbox et l’organiser plus tard.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        bloc.add(const CaptureSaveToInboxRequested()),
                    icon: const Icon(Icons.inbox_outlined),
                    label: const Text('Enregistrer tel quel dans l’inbox'),
                  ),
                  OutlinedButton(
                    onPressed: () => bloc.add(const CaptureOrganizeRequested()),
                    child: const Text('Réessayer'),
                  ),
                  TextButton(
                    onPressed: () => bloc.add(const CaptureReset()),
                    child: const Text('Annuler'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
