import 'package:flutter/material.dart';

import '../widgets/models_install_view.dart';

/// Full-screen models screen, mounted on the `/models` route (pushed from
/// « Réglages → Modèles »). Same content as the last onboarding step, but
/// with the AppBar back button instead of the setup leave actions.
class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modèles locaux')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // Mobile-first: full width on phones, a centered column on
              // tablet/desktop (same layout as the onboarding page).
              constraints: const BoxConstraints(maxWidth: 480),
              child: const ModelsInstallView(),
            ),
          ),
        ),
      ),
    );
  }
}
