import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/capture_bloc.dart';
import '../bloc/dictation_transcript.dart';

/// Live dictation: pulsating mic indicator, live transcript with the
/// revisable partial rendered in italics, and a stop toggle.
class DictationView extends StatelessWidget {
  const DictationView({super.key, required this.transcript});

  final DictationTranscript transcript;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<CaptureBloc>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.errorContainer,
                    child: Icon(
                      Icons.mic,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Dictée en cours…', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: transcript.isEmpty
                        ? Text(
                            'Parlez, le texte apparaît ici…',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: transcript.committed),
                                if (transcript.partial.isNotEmpty)
                                  TextSpan(
                                    text: transcript.committed.isEmpty
                                        ? transcript.partial
                                        : ' ${transcript.partial}',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            style: theme.textTheme.bodyLarge,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => bloc.add(const CaptureDictationStopped()),
                    icon: const Icon(Icons.stop),
                    label: const Text('Arrêter la dictée'),
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
