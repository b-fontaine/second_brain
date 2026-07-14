import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../zettel/domain/entities/inbox_item.dart';
import '../bloc/capture_bloc.dart';
import '../widgets/assistant_unavailable_view.dart';
import '../widgets/capture_sources_view.dart';
import '../widgets/dictation_view.dart';
import '../widgets/drafts_review_view.dart';
import '../widgets/extracted_text_view.dart';
import '../widgets/extraction_progress_view.dart';

/// Capture screen (route `/capture`): the four ingestion assistants
/// (clipboard, audio file, screenshot OCR, dictation).
class CapturePage extends StatelessWidget {
  const CapturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CaptureBloc>(),
      child: const _CaptureView(),
    );
  }
}

class _CaptureView extends StatelessWidget {
  const _CaptureView();

  String _extractionLabel(CaptureType type) => switch (type) {
    CaptureType.clipboard => 'Lecture du presse-papiers…',
    CaptureType.audio => 'Transcription du fichier audio…',
    CaptureType.screenshot => 'Reconnaissance du texte de l’image…',
    CaptureType.dictation => 'Préparation de la dictée…',
  };

  @override
  Widget build(BuildContext context) {
    // No local AppBar: the AdaptiveScaffold shell already titles the tab.
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<CaptureBloc, CaptureState>(
          builder: (context, state) => switch (state) {
            CaptureIdle() => const CaptureSourcesView(),
            CaptureModelInstalling(:final progress) => ExtractionProgressView(
              label:
                  'Téléchargement du modèle de reconnaissance vocale… '
                  'Cette opération n’a lieu qu’au premier usage.',
              progress: progress,
            ),
            CaptureExtracting(:final type) => ExtractionProgressView(
              label: _extractionLabel(type),
            ),
            CaptureDictationRunning(:final transcript) => DictationView(
              transcript: transcript,
            ),
            CaptureTextEditing() => ExtractedTextView(state: state),
            CaptureOrganizing() => const ExtractionProgressView(
              label:
                  'L’assistant organise votre capture en notes '
                  'atomiques…',
            ),
            CaptureAssistantUnavailable() => AssistantUnavailableView(
              state: state,
            ),
            CaptureDraftsReview() => DraftsReviewView(state: state),
            CaptureSuccess() => _SuccessView(state: state),
            CaptureFailed(:final message) => _ErrorView(message: message),
          },
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.state});

  final CaptureSuccess state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<CaptureBloc>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              state.message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => bloc.add(const CaptureReset()),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle capture'),
                ),
                if (state.createdCount > 0)
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Voir mes notes'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

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
                Icons.error_outline,
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => bloc.add(const CaptureReset()),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
