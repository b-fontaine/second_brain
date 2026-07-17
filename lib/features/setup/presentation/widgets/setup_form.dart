import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/serre_tokens.dart';
import '../../domain/usecases/git_remote_url_validator.dart';
import '../bloc/setup_bloc.dart';

/// Welcome header + the two onboarding paths as cards, on a single
/// scrollable screen:
/// - « Nouveau jardin » — local-only vault on this device;
/// - « Reprendre un dépôt git » — clone an existing remote (URL + token).
///
/// The URL/token verification stays the existing [SetupBloc] flow; its
/// outcome is surfaced inline in the remote card (the invalid-URL message
/// directly under the URL field, clone/token failures under the token
/// field). The token goes straight to the system keychain and is never
/// displayed nor logged.
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
    // The URL rejection surfaces inline on its own field; every other
    // failure (refused token, clone error…) under the token field.
    final isUrlError =
        errorMessage == GitRemoteUrlValidator.invalidUrlMessage;

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
          'Choisissez comment démarrer votre jardin de notes.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _LocalCard(isBusy: isBusy),
        const SizedBox(height: 16),
        _RemoteCard(
          isBusy: isBusy,
          urlController: _urlController,
          tokenController: _tokenController,
          urlErrorText: isUrlError ? errorMessage : null,
          errorText: isUrlError ? null : errorMessage,
          onSubmit: () => _submitRemote(context),
        ),
        if (isBusy) ...[
          const SizedBox(height: 24),
          _SetupProgress(
            label: state is SetupCloning
                ? 'Clonage du dépôt en cours…'
                : 'Préparation du coffre…',
          ),
        ],
      ],
    );
  }
}

/// « Nouveau jardin » : local-only vault, nothing to configure.
class _LocalCard extends StatelessWidget {
  const _LocalCard({required this.isBusy});

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return Card(
      key: const Key('setup_local_card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardHeader(
              icon: Icons.spa_outlined,
              title: 'Nouveau jardin',
              subtitle: 'Un coffre local, sans synchronisation',
            ),
            const SizedBox(height: 8),
            Text(
              'Vos notes vivent uniquement sur cet appareil. Vous pourrez '
              'relier un dépôt git plus tard depuis les réglages.',
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.sub),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: isBusy
                  ? null
                  : () => context.read<SetupBloc>().add(
                      const SetupLocalOnlyRequested(),
                    ),
              child: const Text('Continuer sans synchronisation'),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Reprendre un dépôt git » : clone an existing remote with a personal
/// access token kept in the system keychain.
class _RemoteCard extends StatelessWidget {
  const _RemoteCard({
    required this.isBusy,
    required this.urlController,
    required this.tokenController,
    required this.urlErrorText,
    required this.errorText,
    required this.onSubmit,
  });

  final bool isBusy;
  final TextEditingController urlController;
  final TextEditingController tokenController;

  /// « URL de dépôt invalide », inline under the URL field.
  final String? urlErrorText;

  /// Any other failure (refused token, clone error…).
  final String? errorText;

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    final errorText = this.errorText;
    return Card(
      key: const Key('setup_remote_card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardHeader(
              icon: Icons.cloud_outlined,
              title: 'Reprendre un dépôt git',
              subtitle: 'Synchronisation entre vos appareils',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('repo_url_field'),
              controller: urlController,
              enabled: !isBusy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'URL du dépôt git',
                hintText: 'https://github.com/utilisateur/notes.git',
                errorText: urlErrorText,
              ),
              onSubmitted: isBusy ? null : (_) => onSubmit(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('token_field'),
              controller: tokenController,
              enabled: !isBusy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: "Jeton d'accès",
                helperText: 'PAT GitHub/GitLab',
              ),
              onSubmitted: isBusy ? null : (_) => onSubmit(),
            ),
            const SizedBox(height: 8),
            Text(
              'Le jeton est conservé dans le trousseau système, jamais '
              'affiché. La connexion au dépôt est vérifiée pendant le '
              'clonage.',
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.sub),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                errorText,
                key: const Key('setup_error_text'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: isBusy ? null : onSubmit,
              child: const Text('Cloner et démarrer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon + title + functional subtitle row shared by the two cards.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: tokens.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.sub),
              ),
            ],
          ),
        ),
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
