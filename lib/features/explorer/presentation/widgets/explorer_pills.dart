import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/serre_tokens.dart';
// Cross-feature imports — documented exception: the sync status pill reads
// the cubit and entities exposed by the sync feature (same source of truth
// as the AppBar indicator).
import '../../../sync/domain/entities/sync_status.dart';
import '../../../sync/presentation/bloc/sync_status_cubit.dart';
import '../bloc/seedling_count_cubit.dart';

/// Status pills shown under the Explorer search bar: pending seedlings
/// (« n semis »), git sync state, and — expanded layouts only — the toggle
/// of the side notes list.
class ExplorerPills extends StatelessWidget {
  const ExplorerPills({super.key, this.onToggleNotesList});

  /// Expanded layouts: toggles the left chronological notes panel.
  /// Null on compact layouts (the notes list lives in the bottom sheet).
  final VoidCallback? onToggleNotesList;

  @override
  Widget build(BuildContext context) {
    final onToggleNotesList = this.onToggleNotesList;
    return Row(
      children: [
        const _SeedlingPill(),
        const SizedBox(width: 8),
        const SyncStatusPill(),
        if (onToggleNotesList != null) ...[
          const Spacer(),
          IconButton(
            tooltip: 'Liste des notes',
            onPressed: onToggleNotesList,
            icon: const Icon(Icons.view_list_outlined),
          ),
        ],
      ],
    );
  }
}

/// « n semis » : pending captures awaiting review in the pépinière.
/// Hidden while the inbox is empty.
class _SeedlingPill extends StatelessWidget {
  const _SeedlingPill();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SerreTokens>()!;
    return BlocBuilder<SeedlingCountCubit, int>(
      builder: (context, count) {
        if (count <= 0) return const SizedBox.shrink();
        return _StatusPill(
          key: const Key('explorer-seedling-pill'),
          dotColor: tokens.ambre,
          label: '$count semis',
          // TODO(serre-chantier-3): navigate to the « Pépinière » review
          // screen (`/pepiniere`) once chantier 3 adds its route.
          onTap: null,
        );
      },
    );
  }
}

/// Git synchronization pill: « À jour » green, « Hors ligne » amber, etc.
///
/// Creates its own [SyncStatusCubit] via getIt, like the AppBar
/// [SyncStatusIndicator] — both follow the same repository streams.
class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SyncStatusCubit>()..start(),
      child: const _SyncStatusPillBody(),
    );
  }
}

class _SyncStatusPillBody extends StatelessWidget {
  const _SyncStatusPillBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatusState>(
      builder: (context, state) {
        switch (state) {
          case SyncStatusInitial():
            return const SizedBox.shrink();
          case SyncStatusReady(:final status, :final isOnline):
            return _buildPill(context, status, isOnline);
        }
      },
    );
  }

  Widget _buildPill(BuildContext context, SyncStatus status, bool isOnline) {
    final tokens = Theme.of(context).extension<SerreTokens>()!;
    void forceSync() => context.read<SyncStatusCubit>().forceSync();
    const pillKey = Key('explorer-sync-pill');

    if (status.state == SyncState.localOnly) {
      return const _StatusPill(
        key: pillKey,
        dotColor: null,
        label: 'Local uniquement',
      );
    }
    if (status.state == SyncState.syncing) {
      return _StatusPill(
        key: pillKey,
        dotColor: tokens.ambre,
        label: 'Synchronisation…',
      );
    }
    if (status.state == SyncState.error) {
      return _StatusPill(
        key: pillKey,
        dotColor: Theme.of(context).colorScheme.error,
        label: 'Erreur de synchro',
        onTap: forceSync,
      );
    }
    if (!isOnline) {
      return _StatusPill(
        key: pillKey,
        dotColor: tokens.ambre,
        label: 'Hors ligne',
      );
    }
    if (status.state == SyncState.pendingPush) {
      final count = status.pendingCommits;
      return _StatusPill(
        key: pillKey,
        dotColor: tokens.ambre,
        label: '$count en attente',
        onTap: forceSync,
      );
    }
    return _StatusPill(
      key: pillKey,
      dotColor: tokens.accent,
      label: 'À jour',
      onTap: forceSync,
    );
  }
}

/// Small stadium pill: colored status dot plus label.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    super.key,
    required this.dotColor,
    required this.label,
    this.onTap,
  });

  /// Status dot color; no dot when null.
  final Color? dotColor;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return Material(
      color: tokens.surface,
      shape: StadiumBorder(side: BorderSide(color: tokens.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: tokens.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
