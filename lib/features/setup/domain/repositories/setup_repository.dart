import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/vault_config.dart';

/// First-run configuration of the vault and its optional git remote.
///
/// The access token is stored in the platform secure storage,
/// never in the vault or the config file.
abstract interface class SetupRepository {
  /// Null when the app has never been configured (first run).
  Future<Either<Failure, VaultConfig?>> getConfig();

  /// Validates [remoteUrl], clones it, stores the token securely and
  /// persists the resulting [VaultConfig].
  Future<Either<Failure, VaultConfig>> configureWithRemote({
    required String remoteUrl,
    required String token,
  });

  /// Creates an empty local-only vault.
  Future<Either<Failure, VaultConfig>> configureLocalOnly();
}
