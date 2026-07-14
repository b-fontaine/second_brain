import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/capture_bloc.dart';
import '../utils/capture_file_pickers.dart';
import 'capture_source_card.dart';

/// Mode selection: the four ingestion assistant cards.
class CaptureSourcesView extends StatelessWidget {
  const CaptureSourcesView({super.key});

  Future<void> _pickAndAdd(
    BuildContext context,
    Future<CaptureEvent?> Function() picker,
  ) async {
    // Resolved before the async gap: the picker dialog outlives rebuilds.
    final bloc = context.read<CaptureBloc>();
    final event = await picker();
    if (event != null) bloc.add(event);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CaptureBloc>();
    final cards = <Widget>[
      CaptureSourceCard(
        icon: Icons.content_paste,
        title: 'Presse-papiers',
        subtitle: 'Importer le texte ou l’image copiés',
        onTap: () => bloc.add(const CaptureClipboardRequested()),
      ),
      CaptureSourceCard(
        icon: Icons.audio_file_outlined,
        title: 'Fichier audio',
        subtitle: 'Transcrire un enregistrement vocal (WAV)',
        onTap: () => _pickAndAdd(context, pickAudioFileEvent),
      ),
      CaptureSourceCard(
        icon: Icons.screenshot_monitor_outlined,
        title: 'Capture d’écran',
        subtitle: 'Extraire le texte d’une image (OCR)',
        onTap: () => _pickAndAdd(context, pickScreenshotEvent),
        secondaryActionLabel: isDesktopPlatform ? 'Coller une image' : null,
        onSecondaryAction: isDesktopPlatform
            ? () => bloc.add(const CapturePasteImageRequested())
            : null,
      ),
      CaptureSourceCard(
        icon: Icons.mic_none,
        title: 'Dictée',
        subtitle: 'Dicter une note au microphone',
        onTap: () => bloc.add(const CaptureDictationStarted()),
      ),
    ];

    final isExpanded = Breakpoints.isExpanded(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Que souhaitez-vous capturer ?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (isExpanded)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 3.2,
                  children: cards,
                )
              else
                Column(
                  children: [
                    for (final card in cards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: card,
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
