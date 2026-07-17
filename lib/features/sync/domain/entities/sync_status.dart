import 'package:equatable/equatable.dart';

enum SyncState {
  /// No remote configured; vault is local-only.
  localOnly,

  /// Everything committed and pushed.
  upToDate,

  /// Local commits waiting to be pushed (offline or push failed).
  pendingPush,

  /// A sync operation is running.
  syncing,

  /// Last sync attempt failed.
  error,
}

class SyncStatus extends Equatable {
  const SyncStatus({
    required this.state,
    this.pendingCommits = 0,
    this.lastSyncedAt,
    this.message,
    this.conflictCount = 0,
  });

  final SyncState state;
  final int pendingCommits;
  final DateTime? lastSyncedAt;

  /// Error detail when [state] is [SyncState.error].
  final String? message;

  /// Conflicts resolved local-wins by the most recent pull. The remote
  /// copy of each conflicted file is saved under `conflicts/` BEFORE the
  /// resolution, so nothing is ever lost. Reset by the next conflict-free
  /// pull.
  final int conflictCount;

  /// True when the last pull had to resolve conflicts (amber card/toast).
  bool get hasConflicts => conflictCount > 0;

  @override
  List<Object?> get props => [
    state,
    pendingCommits,
    lastSyncedAt,
    message,
    conflictCount,
  ];
}
