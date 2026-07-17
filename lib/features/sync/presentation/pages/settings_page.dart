import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/serre_tokens.dart';
import '../../domain/entities/sync_status.dart';
import '../bloc/settings_cubit.dart';

/// Settings screen, mounted on the `/settings` route (pushed full-screen,
/// outside the shell). Four cards — Synchronisation, Jeton d'accès,
/// Jardin, Modèles — plus an amber conflict card when the last pull had to
/// resolve conflicts (remote copies saved under `conflicts/`).
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

  /// Amber conflict card body (mirrors the shell toast wording).
  static const conflictCardMessage =
      'La copie distante est conservée dans conflicts/ — vos notes '
      'n’ont rien perdu.';

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
    final hasConflicts = state.syncStatus?.hasConflicts ?? false;
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
              if (hasConflicts) ...[
                _ConflictCard(count: state.syncStatus!.conflictCount),
                const SizedBox(height: 16),
              ],
              _SyncCard(state: state),
              if (state.hasRemote) ...[
                const SizedBox(height: 16),
                _TokenCard(state: state),
              ],
              const SizedBox(height: 16),
              _GardenCard(state: state),
              const SizedBox(height: 16),
              const _ModelsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + title + functional subtitle row shared by every settings card.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor ?? tokens.accent),
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

/// Amber card shown when the last pull resolved conflicts local-wins: the
/// remote copies are safe under `conflicts/`, nothing was lost.
class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return Card(
      key: const Key('settings_conflict_card'),
      margin: EdgeInsets.zero,
      color: tokens.ambre.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.ambre),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardHeader(
              icon: Icons.call_merge_outlined,
              iconColor: tokens.ambre,
              title: 'Conflit de synchronisation résolu',
              subtitle: count > 1
                  ? '$count fichiers étaient modifiés des deux côtés'
                  : '1 fichier était modifié des deux côtés',
            ),
            const SizedBox(height: 8),
            Text(
              SettingsView.conflictCardMessage,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// « Synchronisation » : remote overview, current status and manual sync.
class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.state});

  final SettingsLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    final isBusy = state is SettingsTesting || state is SettingsSaving;
    return Card(
      key: const Key('settings_sync_card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardHeader(
              icon: Icons.sync_outlined,
              title: 'Synchronisation',
              subtitle: 'Vos notes suivies par git',
            ),
            const SizedBox(height: 12),
            if (!state.hasRemote) ...[
              const _SummaryRow(
                icon: Icons.cloud_off,
                label: 'Dépôt distant',
                value: 'Aucun dépôt distant configuré',
              ),
              const SizedBox(height: 8),
              Text(
                'La synchronisation n\'est pas configurée pour ce coffre. '
                'Vos notes restent stockées uniquement sur cet appareil.',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.sub),
              ),
            ] else ...[
              _SummaryRow(
                icon: Icons.cloud_outlined,
                label: 'Dépôt distant',
                value: state.remoteUrl!,
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                icon: Icons.sync_outlined,
                label: 'Statut',
                value: _statusLabel(state.syncStatus),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('settings_force_sync_button'),
                onPressed: isBusy
                    ? null
                    : () => context.read<SettingsCubit>().forceSync(),
                icon: const Icon(Icons.sync),
                label: const Text('Forcer la synchronisation'),
              ),
            ],
          ],
        ),
      ),
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

/// « Jeton d'accès » : renewal of the git token kept in the system
/// keychain (never displayed).
class _TokenCard extends StatelessWidget {
  const _TokenCard({required this.state});

  final SettingsLoaded state;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('settings_token_card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardHeader(
              icon: Icons.key_outlined,
              title: 'Jeton d\'accès',
              subtitle: state.hasStoredToken
                  ? 'Jeton enregistré dans le trousseau système'
                  : 'Aucun jeton enregistré',
            ),
            const SizedBox(height: 12),
            _TokenForm(state: state),
          ],
        ),
      ),
    );
  }
}

/// « Jardin » : where the vault lives and how it grows.
class _GardenCard extends StatelessWidget {
  const _GardenCard({required this.state});

  final SettingsLoaded state;

  @override
  Widget build(BuildContext context) {
    final noteCount = state.noteCount;
    return Card(
      key: const Key('settings_garden_card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardHeader(
              icon: Icons.park_outlined,
              title: 'Jardin',
              subtitle: 'Votre coffre de notes markdown',
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              icon: Icons.folder_outlined,
              label: 'Emplacement',
              value: state.vaultPath ?? 'Emplacement inconnu',
            ),
            if (noteCount != null) ...[
              const SizedBox(height: 8),
              _SummaryRow(
                icon: Icons.notes_outlined,
                label: 'Notes cultivées',
                value: noteCount > 1 ? '$noteCount notes' : '$noteCount note',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// « Modèles » : link to the models screen (voice + assistant downloads).
class _ModelsCard extends StatelessWidget {
  const _ModelsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('settings_models_card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardHeader(
              icon: Icons.download_outlined,
              title: 'Modèles locaux',
              subtitle: 'Dictée, transcription et assistant hors ligne',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('settings_models_button'),
              onPressed: () => context.push(AppRoutes.models),
              child: const Text('Gérer les modèles'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small icon + label + value row used by the sync and garden cards.
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

/// Token renewal form: test the connection with a candidate token, or save
/// it atomically (test + persist).
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
