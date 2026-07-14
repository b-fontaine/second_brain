import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/services/network_info.dart';
import 'package:second_brain/core/services/vault_locator.dart';
import 'package:second_brain/features/sync/domain/entities/sync_status.dart';
import 'package:second_brain/features/sync/domain/repositories/git_sync_repository.dart';

/// Controllable in-memory git backend implementing the domain contract.
///
/// Scripting:
/// - Read [cloneCalled] / [clonedRemoteUrl] / [clonedToken] / [initCalled]
///   after an onboarding flow to assert what happened.
/// - Every [commitAll] appends to [commitMessages] and bumps
///   [pendingCommits]; a successful [synchronize] moves them to
///   [pushedCommits] (or fails with [OfflineFailure] when the injected
///   [FakeNetworkInfo]-backed [NetworkInfo] says offline).
/// - Force outcomes with [cloneFailure] / [synchronizeFailure], or push an
///   arbitrary status with [setStatus].
class FakeGitSyncRepository implements GitSyncRepository {
  FakeGitSyncRepository(this._vaultLocator, this._networkInfo);

  final VaultLocator _vaultLocator;
  final NetworkInfo _networkInfo;

  bool cloneCalled = false;
  String? clonedRemoteUrl;
  String? clonedToken;
  bool initCalled = false;
  bool remoteConfigured = false;

  final List<String> commitMessages = [];
  int pendingCommits = 0;
  int pushedCommits = 0;
  int synchronizeCalls = 0;

  /// When non-null, the next [cloneRemote] fails with this failure.
  Failure? cloneFailure;

  /// When non-null, every [synchronize] fails with this failure.
  Failure? synchronizeFailure;

  SyncStatus _status = const SyncStatus(state: SyncState.localOnly);

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  SyncStatus get status => _status;

  /// Replaces the current status and emits it on [watchStatus].
  void setStatus(SyncStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  @override
  Future<Either<Failure, Unit>> cloneRemote({
    required String remoteUrl,
    required String token,
  }) async {
    cloneCalled = true;
    clonedRemoteUrl = remoteUrl;
    clonedToken = token;
    final failure = cloneFailure;
    if (failure != null) {
      cloneFailure = null;
      return Left(failure);
    }
    await _createVaultStructure();
    remoteConfigured = true;
    setStatus(const SyncStatus(state: SyncState.upToDate));
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> initLocal() async {
    initCalled = true;
    setStatus(const SyncStatus(state: SyncState.localOnly));
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> commitAll(String message) async {
    commitMessages.add(message);
    pendingCommits += 1;
    setStatus(
      SyncStatus(
        state: remoteConfigured ? SyncState.pendingPush : SyncState.localOnly,
        pendingCommits: pendingCommits,
      ),
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> synchronize() async {
    synchronizeCalls += 1;
    final failure = synchronizeFailure;
    if (failure != null) {
      setStatus(
        SyncStatus(
          state: SyncState.error,
          pendingCommits: pendingCommits,
          message: failure.message,
        ),
      );
      return Left(failure);
    }
    if (!await _networkInfo.isConnected) {
      setStatus(
        SyncStatus(
          state: remoteConfigured ? SyncState.pendingPush : SyncState.localOnly,
          pendingCommits: pendingCommits,
        ),
      );
      return const Left(OfflineFailure());
    }
    pushedCommits += pendingCommits;
    pendingCommits = 0;
    setStatus(
      SyncStatus(
        state: remoteConfigured ? SyncState.upToDate : SyncState.localOnly,
      ),
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, SyncStatus>> getStatus() async => Right(_status);

  @override
  Stream<SyncStatus> watchStatus() => _statusController.stream;

  Future<void> dispose() => _statusController.close();

  /// A "clone" of an empty remote: the vault folders, nothing else.
  /// Sync IO on purpose: async dart:io never completes under the FakeAsync
  /// zone of testWidgets.
  Future<void> _createVaultStructure() async {
    final root = await _vaultLocator.vaultPath();
    if (root == null || root.isEmpty) return;
    for (final folder in const ['zettel', 'inbox', 'assets']) {
      Directory(p.join(root, folder)).createSync(recursive: true);
    }
  }
}
