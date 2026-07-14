import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../../core/error/failures.dart';
import '../../../core/services/clock.dart';
import '../../../core/services/network_info.dart';
import '../../../core/services/vault_write_notifier.dart';
import '../../zettel/domain/repositories/zettel_repository.dart';
import '../data/services/pull_change_notifier.dart';
import '../domain/repositories/git_sync_repository.dart';

/// Background coordinator of the offline-first git synchronization.
///
/// Started once by the shell at app startup. It:
/// - debounces vault changes (2 s) — zettel edits and raw vault writes
///   such as inbox captures — then commits them locally and, when the
///   network is available, synchronizes with the remote;
/// - synchronizes when connectivity comes back and commits are pending;
/// - relays "remote changes applied by a pull" events so the zettel data
///   layer can re-index the vault.
///
/// No operation ever blocks the UI: every failure ends up as a
/// SyncStatus(error) on the repository stream, and failed synchronizations
/// back off for 30 s to avoid retry storms. Requests discarded while a
/// sync is running (or during the backoff window) are replayed instead of
/// being silently dropped, so no commit ever stays local indefinitely.
@lazySingleton
class SyncOrchestrator {
  SyncOrchestrator(
    this._syncRepository,
    this._zettelRepository,
    this._networkInfo,
    this._pullChangeNotifier,
    this._vaultWriteNotifier,
    this._clock,
  ) : debounceDelay = const Duration(seconds: 2),
      errorBackoff = const Duration(seconds: 30);

  @visibleForTesting
  SyncOrchestrator.withTimings(
    this._syncRepository,
    this._zettelRepository,
    this._networkInfo,
    this._pullChangeNotifier,
    this._vaultWriteNotifier,
    this._clock, {
    required this.debounceDelay,
    required this.errorBackoff,
  });

  static const _autoCommitMessage = 'note: sauvegarde automatique';

  final GitSyncRepository _syncRepository;
  final ZettelRepository _zettelRepository;
  final NetworkInfo _networkInfo;
  final PullChangeNotifier _pullChangeNotifier;
  final VaultWriteNotifier _vaultWriteNotifier;
  final Clock _clock;

  /// Delay between the last vault change and the automatic commit.
  final Duration debounceDelay;

  /// Minimum delay before retrying after a failed synchronization.
  final Duration errorBackoff;

  final _remoteChangesController = StreamController<void>.broadcast();

  /// Emits after a pull applied remote changes to vault files. The shell
  /// wires this to the zettel data layer (notifyExternalChange) so lists
  /// and indexes refresh.
  Stream<void> get remoteChangesApplied => _remoteChangesController.stream;

  StreamSubscription<VaultChanged>? _vaultSubscription;
  StreamSubscription<bool>? _networkSubscription;
  StreamSubscription<void>? _pullSubscription;
  StreamSubscription<void>? _vaultWriteSubscription;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  bool _started = false;
  bool _synchronizing = false;
  bool _resyncRequested = false;
  DateTime? _lastFailureAt;

  /// Begins listening to vault changes and connectivity. Idempotent.
  void start() {
    if (_started) return;
    _started = true;
    _vaultSubscription = _zettelRepository.watchVault().listen(
      _onVaultChanged,
      onError: (Object _) {
        // A broken vault watcher must never crash the sync loop.
      },
    );
    _networkSubscription = _networkInfo.onStatusChange.listen(
      (online) => unawaited(_onConnectivityChanged(online)),
      onError: (Object _) {},
    );
    _pullSubscription = _pullChangeNotifier.changes.listen((_) {
      if (!_remoteChangesController.isClosed) {
        _remoteChangesController.add(null);
      }
    });
    // Inbox captures (and other raw vault writes) do not go through the
    // zettel repository stream but must be committed and pushed too.
    _vaultWriteSubscription = _vaultWriteNotifier.changes.listen(
      (_) => _onVaultChanged(const VaultChanged()),
      onError: (Object _) {},
    );
  }

  /// Stops listening without closing the exposed streams. Idempotent.
  void stop() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _vaultSubscription?.cancel();
    _vaultSubscription = null;
    _networkSubscription?.cancel();
    _networkSubscription = null;
    _pullSubscription?.cancel();
    _pullSubscription = null;
    _vaultWriteSubscription?.cancel();
    _vaultWriteSubscription = null;
    _started = false;
  }

  void _onVaultChanged(VaultChanged _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDelay, () {
      unawaited(_commitThenSync());
    });
  }

  Future<void> _commitThenSync() async {
    // Failures surface as SyncStatus(error) through the repository stream;
    // nothing to rethrow here.
    await _syncRepository.commitAll(_autoCommitMessage);
    if (await _networkInfo.isConnected) {
      await _synchronize();
    }
  }

  Future<void> _onConnectivityChanged(bool online) async {
    if (!online) return;
    final status = await _syncRepository.getStatus();
    final pending = status.fold((_) => 0, (s) => s.pendingCommits);
    if (pending > 0) {
      await _synchronize();
    }
  }

  Future<void> _synchronize() async {
    if (_synchronizing) {
      // A synchronization is already running: replay the request once it
      // completes instead of dropping it — a commit created meanwhile
      // would otherwise stay local until the next unrelated event.
      _resyncRequested = true;
      return;
    }
    final lastFailure = _lastFailureAt;
    if (lastFailure != null) {
      final elapsed = _clock.now().difference(lastFailure);
      if (elapsed < errorBackoff) {
        // Simple backoff: no retry storm after an error, but the discarded
        // request is rescheduled for when the window closes.
        _scheduleRetry(errorBackoff - elapsed);
        return;
      }
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _synchronizing = true;
    try {
      final result = await _syncRepository.synchronize();
      result.fold((failure) {
        // Being offline is not an error: the connectivity listener will
        // retry as soon as the network comes back.
        if (failure is! OfflineFailure) _lastFailureAt = _clock.now();
      }, (_) => _lastFailureAt = null);
    } catch (_) {
      // The repository never throws by contract; last-resort guard so the
      // orchestrator can never crash the app.
      _lastFailureAt = _clock.now();
    } finally {
      _synchronizing = false;
    }
    if (_resyncRequested) {
      _resyncRequested = false;
      await _synchronize();
    }
  }

  void _scheduleRetry(Duration delay) {
    if (_retryTimer?.isActive ?? false) return;
    _retryTimer = Timer(delay, () => unawaited(_synchronize()));
  }

  @disposeMethod
  Future<void> dispose() {
    stop();
    return _remoteChangesController.close();
  }
}
