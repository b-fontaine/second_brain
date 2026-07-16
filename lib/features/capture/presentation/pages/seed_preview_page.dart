import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../bloc/seed_intake_cubit.dart';
import '../widgets/extraction_progress_view.dart';
import '../widgets/seed_preview_form.dart';

/// « Aperçu avant semis » : full-screen preview of a Coller/Fichier capture,
/// pushed above the shell by the seed dial chips. The detected type, the
/// extracted text, the proposed title and parcelles are all reviewable
/// before the draft is sown into the inbox nursery (Pépinière).
class SeedPreviewPage extends StatelessWidget {
  const SeedPreviewPage({super.key, required this.source});

  final SeedSource source;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SeedIntakeCubit>()..start(source),
      child: const _SeedPreviewView(),
    );
  }
}

class _SeedPreviewView extends StatelessWidget {
  const _SeedPreviewView();

  /// Closes the pushed preview, returns to Explorer and confirms the
  /// seeding. The messenger is the root one (above the shell), so the
  /// SnackBar survives the pop.
  void _finish(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.maybeOf(context);
    if (navigator.canPop()) navigator.pop();
    router?.go(AppRoutes.explorer);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Semis déposé en pépinière — brouillon à valider.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pushed above the shell: the page carries its own AppBar.
    return Scaffold(
      appBar: AppBar(title: const Text('Semer')),
      body: SafeArea(
        child: BlocConsumer<SeedIntakeCubit, SeedIntakeState>(
          listener: (context, state) {
            if (state is SeedIntakeSown) _finish(context);
          },
          builder: (context, state) => switch (state) {
            SeedIntakeAnalyzing(:final modelProgress) => ExtractionProgressView(
              label: modelProgress != null
                  ? 'Téléchargement du modèle de reconnaissance vocale… '
                        'Cette opération n’a lieu qu’au premier usage.'
                  : 'Analyse de la capture…',
              progress: modelProgress,
            ),
            SeedIntakeReady() => SeedPreviewForm(state: state),
            SeedIntakeSown() => const SizedBox.shrink(),
            SeedIntakeFailed(:final message) => _IntakeErrorView(
              message: message,
            ),
          },
        ),
      ),
    );
  }
}

class _IntakeErrorView extends StatelessWidget {
  const _IntakeErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
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
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
