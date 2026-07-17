import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../bloc/setup_bloc.dart';
import '../widgets/models_install_view.dart';
import '../widgets/setup_form.dart';

/// First-run onboarding page, mounted on the `/setup` route.
class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SetupBloc>(),
      child: const SetupView(),
    );
  }
}

/// Bloc-agnostic view, testable with a provided [SetupBloc].
class SetupView extends StatelessWidget {
  const SetupView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<SetupBloc, SetupState>(
          builder: (context, state) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  // Mobile-first: full width on phones, a centered
                  // column on tablet/desktop.
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: state is SetupDone
                      ? const ModelsInstallView(showSetupActions: true)
                      : const SetupForm(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
