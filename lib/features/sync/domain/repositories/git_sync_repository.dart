import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/sync_status.dart';

/// Git-based synchronization of the vault folder.
///
/// The vault stays fully usable offline: [commitAll] is local and cheap,
/// [synchronize] is opportunistic and must never block note saving.
abstract interface class GitSyncRepository {
  /// Clones [remoteUrl] into the vault directory (first-run setup).
  /// [token] is a personal access token used for HTTPS auth.
  Future<Either<Failure, Unit>> cloneRemote({
    required String remoteUrl,
    required String token,
  });

  /// Initializes a local-only repository in the vault directory.
  Future<Either<Failure, Unit>> initLocal();

  /// Stages every change in the vault and commits with [message].
  /// No-op when the working tree is clean.
  Future<Either<Failure, Unit>> commitAll(String message);

  /// Pull --rebase then push. Conflicts resolve local-wins with the
  /// remote version preserved as a copy under `conflicts/` at the vault
  /// root (never lose data).
  Future<Either<Failure, Unit>> synchronize();

  Future<Either<Failure, SyncStatus>> getStatus();

  /// Emits on every status change (commit, push, connectivity...).
  Stream<SyncStatus> watchStatus();

  /// Checks that the remote repository is reachable with the given
  /// credentials by performing a real fetch (diagnostic only: neither the
  /// stored token nor the sync status is modified).
  ///
  /// [tokenOverride] is the candidate token to try; when null, the stored
  /// token is used. Fails with [OfflineFailure] when no network is
  /// available, or a [SyncFailure] with a precise French message when no
  /// vault is configured, the vault has no remote, no token is available,
  /// or the remote rejects the token.
  Future<Either<Failure, Unit>> testRemoteConnection({String? tokenOverride});

  /// Replaces the stored personal access token with [token].
  ///
  /// The token is trimmed and validated (must not be empty), then the
  /// remote connection is tested with it ([testRemoteConnection]); it is
  /// persisted ONLY when that test succeeds — a failing test leaves the
  /// previously stored token untouched.
  Future<Either<Failure, Unit>> updateToken(String token);

  /// Whether a personal access token is currently stored, without ever
  /// exposing its value.
  Future<Either<Failure, bool>> hasStoredToken();
}
