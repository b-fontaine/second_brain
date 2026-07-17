import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/sync_status.dart';
import '../bloc/sync_status_cubit.dart';

/// Small AppBar indicator of the git synchronization state.
///
/// Cloud icon per state (up to date, N pending, animated syncing, error
/// with tooltip, offline). Tapping it triggers a manual synchronization.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuse the shell's shared cubit (SyncShellScope) when present so the
    // status streams carry a single subscription; self-provide one only
    // for standalone usages outside the shell.
    try {
      context.read<SyncStatusCubit>();
      return const _SyncStatusButton();
    } on ProviderNotFoundException {
      return BlocProvider(
        create: (_) => getIt<SyncStatusCubit>()..start(),
        child: const _SyncStatusButton(),
      );
    }
  }
}

class _SyncStatusButton extends StatelessWidget {
  const _SyncStatusButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatusState>(
      builder: (context, state) {
        switch (state) {
          case SyncStatusInitial():
            return const SizedBox.shrink();
          case SyncStatusReady(:final status, :final isOnline):
            return _buildButton(context, status, isOnline);
        }
      },
    );
  }

  Widget _buildButton(BuildContext context, SyncStatus status, bool isOnline) {
    final colorScheme = Theme.of(context).colorScheme;
    void forceSync() => context.read<SyncStatusCubit>().forceSync();

    switch (status.state) {
      case SyncState.localOnly:
        return IconButton(
          tooltip: 'Coffre local uniquement (aucun dépôt distant)',
          onPressed: null,
          icon: const Icon(Icons.cloud_off),
        );
      case SyncState.syncing:
        return IconButton(
          tooltip: 'Synchronisation en cours…',
          onPressed: null,
          icon: const _SpinningIcon(icon: Icons.sync),
        );
      case SyncState.error:
        final detail = status.message;
        return IconButton(
          tooltip: detail == null || detail.isEmpty
              ? 'Erreur de synchronisation'
              : 'Erreur de synchronisation : $detail',
          onPressed: forceSync,
          icon: Icon(Icons.sync_problem, color: colorScheme.error),
        );
      case SyncState.pendingPush:
        final count = status.pendingCommits;
        final icon = Badge(
          label: Text('$count'),
          child: Icon(isOnline ? Icons.cloud_upload : Icons.cloud_off),
        );
        return IconButton(
          tooltip: isOnline
              ? '$count modification(s) à envoyer'
              : 'Hors ligne — $count modification(s) en attente',
          onPressed: isOnline ? forceSync : null,
          icon: icon,
        );
      case SyncState.upToDate:
        if (!isOnline) {
          return IconButton(
            tooltip: 'Hors ligne — tout est sauvegardé localement',
            onPressed: null,
            icon: const Icon(Icons.cloud_off),
          );
        }
        return IconButton(
          tooltip: 'Synchronisé',
          onPressed: forceSync,
          icon: const Icon(Icons.cloud_done),
        );
    }
  }
}

/// Continuously rotating icon used while a synchronization is running.
class _SpinningIcon extends StatefulWidget {
  const _SpinningIcon({required this.icon});

  final IconData icon;

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      // Icons.sync visually reads counter-clockwise, so reverse the turns.
      turns: ReverseAnimation(_controller),
      child: Icon(widget.icon),
    );
  }
}
