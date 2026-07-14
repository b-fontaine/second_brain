import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/capture_bloc.dart';
import 'capture_source_card.dart';

/// Mode selection: the four ingestion assistant cards.
class CaptureSourcesView extends StatelessWidget {
  const CaptureSourcesView({super.key});

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  Future<void> _pickAudioFile(BuildContext context) async {
    final bloc = context.read<CaptureBloc>();
    final group = XTypeGroup(
      label: 'Audio',
      extensions: const ['wav', 'm4a', 'mp3', 'aac', 'flac', 'ogg', 'opus'],
      uniformTypeIdentifiers: const ['public.audio'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file != null) bloc.add(CaptureAudioFilePicked(file.path));
  }

  Future<void> _pickScreenshot(BuildContext context) async {
    final bloc = context.read<CaptureBloc>();
    if (_isDesktop) {
      final group = XTypeGroup(
        label: 'Images',
        extensions: const ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'tiff'],
        uniformTypeIdentifiers: const ['public.image'],
      );
      final file = await openFile(acceptedTypeGroups: [group]);
      if (file != null) bloc.add(CaptureScreenshotPicked(file.path));
    } else {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) bloc.add(CaptureScreenshotPicked(image.path));
    }
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
        onTap: () => _pickAudioFile(context),
      ),
      CaptureSourceCard(
        icon: Icons.screenshot_monitor_outlined,
        title: 'Capture d’écran',
        subtitle: 'Extraire le texte d’une image (OCR)',
        onTap: () => _pickScreenshot(context),
        secondaryActionLabel: _isDesktop ? 'Coller une image' : null,
        onSecondaryAction: _isDesktop
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
