import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/setup_bloc.dart';

/// Welcome header + remote repository form, on a single scrollable
/// screen so the fields are reachable straight from first launch.
class SetupForm extends StatefulWidget {
  const SetupForm({super.key});

  @override
  State<SetupForm> createState() => _SetupFormState();
}

class _SetupFormState extends State<SetupForm> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _submitRemote(BuildContext context) {
    context.read<SetupBloc>().add(
      SetupRemoteSubmitted(
        remoteUrl: _urlController.text,
        token: _tokenController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<SetupBloc>().state;
    final isBusy = state is SetupValidating || state is SetupCloning;
    final errorMessage = state is SetupError ? state.message : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.auto_stories_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Bienvenue dans Second Brain',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Configurer la synchronisation',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Vos notes sont des fichiers markdown stockés sur cet appareil. '
          'Reliez un dépôt git pour les synchroniser entre vos appareils, '
          'ou continuez en local uniquement.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          key: const Key('repo_url_field'),
          controller: _urlController,
          enabled: !isBusy,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'URL du dépôt git',
            hintText: 'https://github.com/utilisateur/notes.git',
          ),
          onSubmitted: isBusy ? null : (_) => _submitRemote(context),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('token_field'),
          controller: _tokenController,
          enabled: !isBusy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: "Jeton d'accès",
            helperText: 'PAT GitHub/GitLab',
          ),
          onSubmitted: isBusy ? null : (_) => _submitRemote(context),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            errorMessage,
            key: const Key('setup_error_text'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (isBusy)
          _SetupProgress(
            label: state is SetupCloning
                ? 'Clonage du dépôt en cours…'
                : 'Préparation du coffre…',
          )
        else ...[
          FilledButton(
            onPressed: () => _submitRemote(context),
            child: const Text('Cloner et démarrer'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                context.read<SetupBloc>().add(const SetupLocalOnlyRequested()),
            child: const Text('Continuer sans synchronisation'),
          ),
        ],
      ],
    );
  }
}

class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(label, textAlign: TextAlign.center),
      ],
    );
  }
}
