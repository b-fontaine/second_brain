import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/clock.dart';
import '../../../../core/services/network_info.dart';
import '../../../../core/services/vault_locator.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/repositories/git_sync_repository.dart';
import '../datasources/git_client.dart';
import '../services/pull_change_notifier.dart';

/// [GitSyncRepository] backed by a [GitClient] over the local vault.
///
/// Keeps the latest [SyncStatus] in memory and replays it to every new
/// [watchStatus] subscriber (BehaviorSubject-like semantics with a plain
/// broadcast controller).
/// Top-level dispose hook: injectable registers the singleton under the
/// [GitSyncRepository] interface, which has no dispose() of its own.
FutureOr<void> disposeGitSyncRepository(GitSyncRepository repository) {
  if (repository is GitSyncRepositoryImpl) return repository.dispose();
}

@LazySingleton(as: GitSyncRepository, dispose: disposeGitSyncRepository)
class GitSyncRepositoryImpl implements GitSyncRepository {
  GitSyncRepositoryImpl(
    this._git,
    this._vaultLocator,
    this._networkInfo,
    this._secureStorage,
    this._clock,
    this._pullChangeNotifier,
  );

  static const tokenKey = 'git_token';
  static const _noVaultMessage = 'Aucun vault configuré';

  final GitClient _git;
  final VaultLocator _vaultLocator;
  final NetworkInfo _networkInfo;
  final FlutterSecureStorage _secureStorage;
  final Clock _clock;
  final PullChangeNotifier _pullChangeNotifier;

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = const SyncStatus(state: SyncState.localOnly);
  DateTime? _lastSyncedAt;

  @override
  Future<Either<Failure, Unit>> cloneRemote({
    required String remoteUrl,
    required String token,
  }) async {
    final path = await _vaultLocator.vaultPath();
    if (path == null) return const Left(SyncFailure(_noVaultMessage));
    try {
      // Persist the token first so later synchronizations can authenticate.
      await _secureStorage.write(key: tokenKey, value: token);
      await _git.clone(url: remoteUrl, path: path, token: token);
      _lastSyncedAt = _clock.now();
      _emit(SyncStatus(state: SyncState.upToDate, lastSyncedAt: _lastSyncedAt));
      return const Right(unit);
    } on GitException catch (e) {
      _emitError(e.message);
      return Left(SyncFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> initLocal() async {
    final path = await _vaultLocator.vaultPath();
    if (path == null) return const Left(SyncFailure(_noVaultMessage));
    try {
      if (!await _git.isRepository(path)) {
        await _git.init(path);
      }
      _emit(const SyncStatus(state: SyncState.localOnly));
      return const Right(unit);
    } on GitException catch (e) {
      _emitError(e.message);
      return Left(SyncFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> commitAll(String message) async {
    final path = await _vaultLocator.vaultPath();
    if (path == null) return const Left(SyncFailure(_noVaultMessage));
    try {
      if (!await _git.isRepository(path)) {
        // Offline-first resilience: a vault must always be committable.
        await _git.init(path);
      }
      await _git.stageAll(path);
      final created = await _git.commit(path: path, message: message);
      if (created) {
        _emit(await _computeStatus(path));
      }
      return const Right(unit);
    } on GitException catch (e) {
      _emitError(e.message);
      return Left(SyncFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> synchronize() async {
    final path = await _vaultLocator.vaultPath();
    if (path == null) return const Left(SyncFailure(_noVaultMessage));
    if (_current.state == SyncState.syncing) {
      // A synchronization is already running: don't pile up.
      return const Right(unit);
    }
    try {
      if (!await _git.isRepository(path) || !await _git.hasRemote(path)) {
        _emit(
          SyncStatus(state: SyncState.localOnly, lastSyncedAt: _lastSyncedAt),
        );
        return const Right(unit);
      }
      if (!await _networkInfo.isConnected) {
        _emit(await _computeStatus(path));
        return const Left(OfflineFailure());
      }
      final token = await _secureStorage.read(key: tokenKey);
      if (token == null || token.isEmpty) {
        const message = 'Aucun jeton d\'accès enregistré';
        _emitError(message);
        return const Left(SyncFailure(message));
      }

      _emit(
        SyncStatus(
          state: SyncState.syncing,
          pendingCommits: _current.pendingCommits,
          lastSyncedAt: _lastSyncedAt,
        ),
      );

      // Pull = fetch + fast-forward-or-merge, conflicts resolved local-wins
      // with the remote copies saved beforehand.
      final pullResult = await _git.pull(path: path, token: token);
      if (pullResult.updated) {
        _pullChangeNotifier.notifyPulledChanges();
      }
      if (await _git.aheadCount(path) > 0) {
        await _git.push(path: path, token: token);
      }

      _lastSyncedAt = _clock.now();
      // Recompute instead of assuming upToDate: a commit created while the
      // pull/push was running must keep showing as pending.
      _emit(await _computeStatus(path));
      return const Right(unit);
    } on GitException catch (e) {
      _emitError(e.message);
      return Left(SyncFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, SyncStatus>> getStatus() async {
    if (_current.state == SyncState.syncing) return Right(_current);
    final path = await _vaultLocator.vaultPath();
    if (path == null) {
      return const Right(SyncStatus(state: SyncState.localOnly));
    }
    try {
      final status = await _computeStatus(path);
      if (status != _current) _emit(status);
      return Right(status);
    } on GitException catch (e) {
      return Left(SyncFailure(e.message));
    }
  }

  @override
  Stream<SyncStatus> watchStatus() async* {
    // Replay the latest value to every new subscriber.
    yield _current;
    yield* _statusController.stream;
  }

  Future<SyncStatus> _computeStatus(String path) async {
    if (!await _git.isRepository(path) || !await _git.hasRemote(path)) {
      return SyncStatus(
        state: SyncState.localOnly,
        lastSyncedAt: _lastSyncedAt,
      );
    }
    final ahead = await _git.aheadCount(path);
    return SyncStatus(
      state: ahead > 0 ? SyncState.pendingPush : SyncState.upToDate,
      pendingCommits: ahead,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  void _emit(SyncStatus status) {
    _current = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void _emitError(String message) {
    _emit(
      SyncStatus(
        state: SyncState.error,
        pendingCommits: _current.pendingCommits,
        lastSyncedAt: _lastSyncedAt,
        message: message,
      ),
    );
  }

  Future<void> dispose() => _statusController.close();
}
