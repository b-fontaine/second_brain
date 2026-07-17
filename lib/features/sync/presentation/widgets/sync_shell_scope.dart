import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/serre_tokens.dart';
import '../../domain/entities/sync_status.dart';
import '../bloc/sync_status_cubit.dart';

/// Provides ONE shared [SyncStatusCubit] to the whole navigation shell —
/// the AppBar indicator, the Explorer pill, the offline banner and the
/// rail dot all reuse it instead of multiplying subscriptions — and
/// surfaces the pedagogical conflict toast when a pull had to resolve
/// conflicts (remote copies saved under `conflicts/`).
class SyncShellScope extends StatelessWidget {
  const SyncShellScope({super.key, required this.child, this.cubit});

  /// Pedagogical toast shown once per rising conflict edge.
  static const conflictToastMessage =
      'Conflit de synchronisation résolu : la copie distante est '
      'conservée dans conflicts/ — vos notes n’ont rien perdu.';

  final Widget child;

  /// Test seam: injected cubit (never closed by the scope); resolved and
  /// started through getIt otherwise.
  final SyncStatusCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final injected = cubit;
    if (injected != null) {
      return BlocProvider.value(
        value: injected,
        child: _ConflictToastListener(child: child),
      );
    }
    return BlocProvider(
      create: (_) => getIt<SyncStatusCubit>()..start(),
      child: _ConflictToastListener(child: child),
    );
  }
}

/// Shows [SyncShellScope.conflictToastMessage] on every 0 → n transition
/// of the conflict count (a pull just resolved conflicts local-wins).
class _ConflictToastListener extends StatelessWidget {
  const _ConflictToastListener({required this.child});

  final Widget child;

  static int _conflictsOf(SyncStatusState state) =>
      state is SyncStatusReady ? state.status.conflictCount : 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SyncStatusCubit, SyncStatusState>(
      listenWhen: (previous, current) =>
          _conflictsOf(previous) == 0 && _conflictsOf(current) > 0,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(SyncShellScope.conflictToastMessage),
            duration: Duration(seconds: 6),
          ),
        );
      },
      child: child,
    );
  }
}

/// Discreet banner above the shell content while local commits wait for
/// connectivity: « n notes attendent la pluie — synchronisation à la
/// reconnexion ». Static (no animation, no indeterminate indicator).
///
/// Must live under a [SyncShellScope] (or any [SyncStatusCubit] provider).
class SyncOfflineBanner extends StatelessWidget {
  const SyncOfflineBanner({super.key, required this.child});

  final Widget child;

  /// Banner wording, exposed for the widget tests.
  static String messageFor(int pendingCommits) => pendingCommits > 1
      ? '$pendingCommits notes attendent la pluie — synchronisation à la '
            'reconnexion'
      : '1 note attend la pluie — synchronisation à la reconnexion';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatusState>(
      builder: (context, state) {
        if (state is! SyncStatusReady ||
            state.isOnline ||
            state.status.state != SyncState.pendingPush ||
            state.status.pendingCommits <= 0) {
          return child;
        }
        final tokens = Theme.of(context).extension<SerreTokens>()!;
        return Column(
          children: [
            Container(
              key: const Key('sync-offline-banner'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: tokens.ambre.withValues(alpha: 0.16),
                border: Border(bottom: BorderSide(color: tokens.line)),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 16, color: tokens.ambre),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      messageFor(state.status.pendingCommits),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// Small amber/green sync heartbeat shown next to the navigation rail's
/// settings gear on expanded layouts. Compact layouts already carry the
/// Explorer « À jour / Hors ligne » pill next to the search bar, so this
/// dot deliberately does not duplicate it there.
///
/// Renders nothing when no [SyncStatusCubit] is provided above (e.g. the
/// shell widget tests that stub every sync dependency out).
class SyncStatusDot extends StatelessWidget {
  const SyncStatusDot({super.key});

  @override
  Widget build(BuildContext context) {
    final SyncStatusCubit cubit;
    try {
      cubit = context.read<SyncStatusCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    return BlocBuilder<SyncStatusCubit, SyncStatusState>(
      bloc: cubit,
      builder: (context, state) {
        if (state is! SyncStatusReady ||
            state.status.state == SyncState.localOnly) {
          return const SizedBox.shrink();
        }
        final tokens = Theme.of(context).extension<SerreTokens>()!;
        final (Color color, String label) = switch (state) {
          SyncStatusReady(:final status)
              when status.state == SyncState.error =>
            (Theme.of(context).colorScheme.error, 'Synchronisation en erreur'),
          SyncStatusReady(:final status, :final isOnline)
              when status.hasConflicts ||
                  !isOnline ||
                  status.state == SyncState.pendingPush ||
                  status.state == SyncState.syncing =>
            (tokens.ambre, 'Synchronisation en attente'),
          _ => (tokens.accent, 'Synchronisation à jour'),
        };
        return Tooltip(
          message: label,
          child: Semantics(
            label: label,
            child: Container(
              key: const Key('sync-status-dot'),
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
        );
      },
    );
  }
}
