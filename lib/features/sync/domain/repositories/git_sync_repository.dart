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
}
