import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/vault_locator.dart';
import '../../../sync/domain/repositories/git_sync_repository.dart';
import '../../domain/entities/vault_config.dart';
import '../../domain/repositories/setup_repository.dart';
import '../../domain/usecases/git_remote_url_validator.dart';
import '../datasources/setup_local_data_source.dart';
import '../models/vault_config_model.dart';

/// Onboarding orchestration: validates input, stores the token, delegates
/// git work to the sync feature and persists the resulting configuration.
@LazySingleton(as: SetupRepository)
class SetupRepositoryImpl implements SetupRepository {
  SetupRepositoryImpl(
    this._localDataSource,
    this._gitSyncRepository,
    this._vaultLocator,
  );

  final SetupLocalDataSource _localDataSource;
  final GitSyncRepository _gitSyncRepository;
  final VaultLocator _vaultLocator;

  @override
  Future<Either<Failure, VaultConfig?>> getConfig() async {
    try {
      return Right(await _localDataSource.getConfig());
    } on VaultException catch (e) {
      return Left(VaultFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, VaultConfig>> configureWithRemote({
    required String remoteUrl,
    required String token,
  }) async {
    final url = remoteUrl.trim();
    if (!GitRemoteUrlValidator.isValid(url)) {
      return const Left(
        ValidationFailure(GitRemoteUrlValidator.invalidUrlMessage),
      );
    }
    try {
      await _localDataSource.storeToken(token);
      final vaultPath = await _localDataSource.defaultVaultPath();
      // The sync feature resolves the clone destination through the
      // VaultLocator, so the path must be published before cloning.
      // A published path marks the app as configured (the router skips
      // onboarding as soon as getConfig() is non-null), so it MUST be
      // rolled back when the clone fails.
      final previousPath = await _vaultLocator.vaultPath();
      await _vaultLocator.setVaultPath(vaultPath);

      final Either<Failure, Unit> cloneResult;
      try {
        cloneResult = await _gitSyncRepository.cloneRemote(
          remoteUrl: url,
          token: token,
        );
      } on Exception {
        await _rollbackVaultPath(previousPath);
        rethrow;
      }
      return await cloneResult.fold<Future<Either<Failure, VaultConfig>>>(
        (failure) async {
          await _rollbackVaultPath(previousPath);
          return Left(failure);
        },
        (_) async {
          // The clone succeeded: the vault is valid, the path stays
          // published even if persisting the config fails below.
          final config = VaultConfigModel(vaultPath: vaultPath, remoteUrl: url);
          await _localDataSource.saveConfig(config);
          return Right(config);
        },
      );
    } on GitException catch (e) {
      return Left(SyncFailure(e.message));
    } on VaultException catch (e) {
      return Left(VaultFailure(e.message));
    }
  }

  /// Restores the vault path published before a failed clone attempt.
  Future<void> _rollbackVaultPath(String? previousPath) async {
    if (previousPath == null) {
      await _vaultLocator.clearVaultPath();
    } else {
      await _vaultLocator.setVaultPath(previousPath);
    }
  }

  @override
  Future<Either<Failure, VaultConfig>> configureLocalOnly() async {
    try {
      final vaultPath = await _localDataSource.defaultVaultPath();
      await _localDataSource.createVaultDirectory(vaultPath);
      // Publish the path before initLocal for the same reason as above.
      await _vaultLocator.setVaultPath(vaultPath);

      final initResult = await _gitSyncRepository.initLocal();
      return await initResult.fold<Future<Either<Failure, VaultConfig>>>(
        (failure) async => Left(failure),
        (_) async {
          await _localDataSource.createLocalVaultStructure(vaultPath);
          final config = VaultConfigModel(vaultPath: vaultPath);
          await _localDataSource.saveConfig(config);
          return Right(config);
        },
      );
    } on GitException catch (e) {
      return Left(SyncFailure(e.message));
    } on VaultException catch (e) {
      return Left(VaultFailure(e.message));
    }
  }
}
