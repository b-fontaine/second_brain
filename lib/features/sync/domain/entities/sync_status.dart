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
  });

  final SyncState state;
  final int pendingCommits;
  final DateTime? lastSyncedAt;

  /// Error detail when [state] is [SyncState.error].
  final String? message;

  @override
  List<Object?> get props => [state, pendingCommits, lastSyncedAt, message];
}
