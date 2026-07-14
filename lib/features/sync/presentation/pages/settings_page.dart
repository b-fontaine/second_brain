import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/sync_status.dart';
import '../bloc/settings_cubit.dart';

/// Settings screen, mounted on the `/settings` route (pushed full-screen,
/// outside the shell). Lets the user renew the git access token and test
/// the connection to the remote repository.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SettingsCubit>()..load(),
      child: const SettingsView(),
    );
  }
}

/// Cubit-agnostic view, testable with a provided [SettingsCubit].
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: SafeArea(
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            return switch (state) {
              SettingsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              SettingsError(:final message) => _LoadError(message: message),
              SettingsLoaded() => _SettingsBody(state: state),
            };
          },
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.state});

  final SettingsLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          // Mobile-first: full width on phones, a centered column on
          // tablet/desktop (same layout as the onboarding form).
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Synchronisation', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              _RemoteSummary(state: state),
              if (state.hasRemote) ...[
                const SizedBox(height: 24),
                _TokenForm(state: state),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only overview: remote url (or local-only notice), token presence
/// and current synchronization status.
class _RemoteSummary extends StatelessWidget {
  const _RemoteSummary({required this.state});

  final SettingsLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!state.hasRemote) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(
            icon: Icons.cloud_off,
            label: 'Dépôt distant',
            value: 'Aucun dépôt distant configuré',
          ),
          const SizedBox(height: 12),
          Text(
            'La synchronisation n\'est pas configurée pour ce coffre. '
            'Vos notes restent stockées uniquement sur cet appareil.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow(
          icon: Icons.cloud_outlined,
          label: 'Dépôt distant',
          value: state.remoteUrl!,
        ),
        const SizedBox(height: 8),
        _SummaryRow(
          icon: Icons.key_outlined,
          label: 'Jeton d\'accès',
          value: state.hasStoredToken ? 'Jeton enregistré' : 'Aucun jeton',
        ),
        const SizedBox(height: 8),
        _SummaryRow(
          icon: Icons.sync_outlined,
          label: 'Statut',
          value: _statusLabel(state.syncStatus),
        ),
      ],
    );
  }

  String _statusLabel(SyncStatus? status) {
    if (status == null) return 'Statut inconnu';
    return switch (status.state) {
      SyncState.localOnly => 'Coffre local uniquement',
      SyncState.upToDate => 'Synchronisé',
      SyncState.pendingPush =>
        '${status.pendingCommits} modification(s) à envoyer',
      SyncState.syncing => 'Synchronisation en cours…',
      SyncState.error =>
        status.message == null || status.message!.isEmpty
            ? 'Erreur de synchronisation'
            : 'Erreur de synchronisation : ${status.message}',
    };
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

/// Token renewal form: test the connection with a candidate token, save it
/// atomically (test + persist), or force a manual synchronization.
class _TokenForm extends StatefulWidget {
  const _TokenForm({required this.state});

  final SettingsLoaded state;

  @override
  State<_TokenForm> createState() => _TokenFormState();
}

class _TokenFormState extends State<_TokenForm> {
  final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The save button enables as soon as the field is non-blank.
    _tokenController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final isBusy = state is SettingsTesting || state is SettingsSaving;
    final canSave = !isBusy && _tokenController.text.trim().isNotEmpty;

    return BlocListener<SettingsCubit, SettingsState>(
      listenWhen: (_, current) => current is SettingsSaved,
      // The saved token must never linger in the (obscured) field.
      listener: (_, _) => _tokenController.clear(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('settings_token_field'),
            controller: _tokenController,
            enabled: !isBusy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Nouveau jeton d\'accès',
              helperText: 'PAT GitHub/GitLab',
            ),
          ),
          const SizedBox(height: 12),
          _Feedback(state: state),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('settings_test_button'),
            onPressed: isBusy
                ? null
                : () => context.read<SettingsCubit>().testConnection(
                    _tokenController.text,
                  ),
            child: const Text('Tester la connexion'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('settings_save_button'),
            onPressed: canSave
                ? () => context.read<SettingsCubit>().saveToken(
                    _tokenController.text,
                  )
                : null,
            child: const Text('Enregistrer'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('settings_force_sync_button'),
            onPressed: isBusy
                ? null
                : () => context.read<SettingsCubit>().forceSync(),
            icon: const Icon(Icons.sync),
            label: const Text('Forcer la synchronisation'),
          ),
          if (isBusy) ...[
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    state is SettingsSaving
                        ? 'Vérification et enregistrement du jeton…'
                        : 'Test de la connexion au dépôt…',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Green success / red failure line under the token field.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.state});

  final SettingsLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String? message, bool isError) = switch (state) {
      SettingsTestSuccess() => ('Connexion au dépôt réussie', false),
      SettingsSaved() => ('Jeton mis à jour', false),
      SettingsTestFailure(:final message) => (message, true),
      SettingsSaveFailure(:final message) => (message, true),
      _ => (null, false),
    };
    if (message == null) return const SizedBox.shrink();
    return Text(
      message,
      key: const Key('settings_feedback_text'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: isError ? theme.colorScheme.error : Colors.green.shade700,
      ),
    );
  }
}
