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
/// - Token management: [storedToken] is the "secure storage" content
///   ([cloneRemote] and a successful [updateToken] fill it). Add a token to
///   [rejectedTokens] to make [testRemoteConnection]/[updateToken] refuse
///   it; every [updateToken] call is traced in [updateTokenCalls].
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

  /// In-memory stand-in for the secure storage `git_token` entry.
  String? storedToken;

  /// Tokens the fake remote refuses (message
  /// 'Jeton refusé par le dépôt distant').
  final Set<String> rejectedTokens = {};

  /// Every raw token passed to [updateToken], in call order.
  final List<String> updateTokenCalls = [];

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
    storedToken = token;
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
  Future<Either<Failure, Unit>> testRemoteConnection({
    String? tokenOverride,
  }) async {
    if (!remoteConfigured) {
      return const Left(
        SyncFailure('Aucun dépôt distant configuré pour ce coffre'),
      );
    }
    if (!await _networkInfo.isConnected) {
      return const Left(OfflineFailure());
    }
    final candidate = tokenOverride ?? storedToken;
    if (candidate == null || candidate.trim().isEmpty) {
      return const Left(SyncFailure('Aucun jeton d\'accès enregistré'));
    }
    if (rejectedTokens.contains(candidate.trim())) {
      return const Left(SyncFailure('Jeton refusé par le dépôt distant'));
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> updateToken(String token) async {
    updateTokenCalls.add(token);
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return const Left(
        ValidationFailure('Le jeton d\'accès ne peut pas être vide'),
      );
    }
    final test = await testRemoteConnection(tokenOverride: trimmed);
    return test.fold(Left.new, (_) {
      // Same contract as the real implementation: persist only after a
      // successful connection test.
      storedToken = trimmed;
      return const Right(unit);
    });
  }

  @override
  Future<Either<Failure, bool>> hasStoredToken() async =>
      Right(storedToken != null && storedToken!.isNotEmpty);

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
