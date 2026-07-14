import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/services/vault_locator.dart';
import 'package:second_brain/features/setup/data/datasources/setup_local_data_source.dart';
import 'package:second_brain/features/setup/data/models/vault_config_model.dart';
import 'package:second_brain/features/setup/data/repositories/setup_repository_impl.dart';
import 'package:second_brain/features/setup/domain/entities/vault_config.dart';
import 'package:second_brain/features/sync/domain/repositories/git_sync_repository.dart';

class MockSetupLocalDataSource extends Mock implements SetupLocalDataSource {}

class MockGitSyncRepository extends Mock implements GitSyncRepository {}

class MockVaultLocator extends Mock implements VaultLocator {}

void main() {
  late MockSetupLocalDataSource localDataSource;
  late MockGitSyncRepository gitSyncRepository;
  late MockVaultLocator vaultLocator;
  late SetupRepositoryImpl repository;

  const vaultPath = '/docs/second_brain_vault';
  const remoteUrl = 'https://github.com/user/zettelkasten.git';
  const token = 'ghp_token123';

  setUpAll(() {
    registerFallbackValue(const VaultConfigModel(vaultPath: ''));
  });

  setUp(() {
    localDataSource = MockSetupLocalDataSource();
    gitSyncRepository = MockGitSyncRepository();
    vaultLocator = MockVaultLocator();
    repository = SetupRepositoryImpl(
      localDataSource,
      gitSyncRepository,
      vaultLocator,
    );
  });

  group('getConfig', () {
    test('returns null on first run', () async {
      when(() => localDataSource.getConfig()).thenAnswer((_) async => null);

      final result = await repository.getConfig();

      expect(result, const Right<Failure, VaultConfig?>(null));
    });

    test('returns the stored config', () async {
      const config = VaultConfigModel(
        vaultPath: vaultPath,
        remoteUrl: remoteUrl,
      );
      when(() => localDataSource.getConfig()).thenAnswer((_) async => config);

      final result = await repository.getConfig();

      expect(result, const Right<Failure, VaultConfig?>(config));
    });

    test('converts VaultException into VaultFailure', () async {
      when(
        () => localDataSource.getConfig(),
      ).thenThrow(const VaultException('lecture impossible'));

      final result = await repository.getConfig();

      expect(
        result,
        const Left<Failure, VaultConfig?>(VaultFailure('lecture impossible')),
      );
    });
  });

  group('configureWithRemote', () {
    void stubHappyPath() {
      when(() => localDataSource.storeToken(any())).thenAnswer((_) async {});
      when(
        () => localDataSource.defaultVaultPath(),
      ).thenAnswer((_) async => vaultPath);
      when(() => vaultLocator.vaultPath()).thenAnswer((_) async => null);
      when(() => vaultLocator.setVaultPath(any())).thenAnswer((_) async {});
      when(() => vaultLocator.clearVaultPath()).thenAnswer((_) async {});
      when(
        () => gitSyncRepository.cloneRemote(
          remoteUrl: any(named: 'remoteUrl'),
          token: any(named: 'token'),
        ),
      ).thenAnswer((_) async => Right(unit));
      when(() => localDataSource.saveConfig(any())).thenAnswer((_) async {});
    }

    test('rejects an invalid url with the exact message '
        'without any side effect', () async {
      final result = await repository.configureWithRemote(
        remoteUrl: 'not-a-url',
        token: token,
      );

      expect(
        result,
        const Left<Failure, VaultConfig>(
          ValidationFailure('URL de dépôt invalide'),
        ),
      );
      verifyZeroInteractions(gitSyncRepository);
      verifyZeroInteractions(localDataSource);
      verifyZeroInteractions(vaultLocator);
    });

    test('stores the token, publishes the vault path, clones and '
        'persists the config', () async {
      stubHappyPath();

      final result = await repository.configureWithRemote(
        remoteUrl: '  $remoteUrl  ',
        token: token,
      );

      expect(
        result,
        const Right<Failure, VaultConfig>(
          VaultConfigModel(vaultPath: vaultPath, remoteUrl: remoteUrl),
        ),
      );
      verifyInOrder([
        () => localDataSource.storeToken(token),
        () => vaultLocator.setVaultPath(vaultPath),
        () => gitSyncRepository.cloneRemote(remoteUrl: remoteUrl, token: token),
        () => localDataSource.saveConfig(
          const VaultConfigModel(vaultPath: vaultPath, remoteUrl: remoteUrl),
        ),
      ]);
    });

    test('propagates a clone failure, does not persist the config and '
        'rolls back the published vault path so the app does not believe '
        'it is configured after a restart', () async {
      stubHappyPath();
      when(
        () => gitSyncRepository.cloneRemote(
          remoteUrl: any(named: 'remoteUrl'),
          token: any(named: 'token'),
        ),
      ).thenAnswer(
        (_) async => const Left(SyncFailure('Échec du clonage : accès refusé')),
      );

      final result = await repository.configureWithRemote(
        remoteUrl: remoteUrl,
        token: token,
      );

      expect(
        result,
        const Left<Failure, VaultConfig>(
          SyncFailure('Échec du clonage : accès refusé'),
        ),
      );
      verifyNever(() => localDataSource.saveConfig(any()));
      verify(() => vaultLocator.clearVaultPath()).called(1);
    });

    test('restores the previous vault path when a re-clone fails', () async {
      stubHappyPath();
      when(
        () => vaultLocator.vaultPath(),
      ).thenAnswer((_) async => '/docs/ancien_vault');
      when(
        () => gitSyncRepository.cloneRemote(
          remoteUrl: any(named: 'remoteUrl'),
          token: any(named: 'token'),
        ),
      ).thenAnswer((_) async => const Left(SyncFailure('accès refusé')));

      final result = await repository.configureWithRemote(
        remoteUrl: remoteUrl,
        token: token,
      );

      expect(result.isLeft(), isTrue);
      verifyNever(() => vaultLocator.clearVaultPath());
      verifyInOrder([
        () => vaultLocator.setVaultPath(vaultPath),
        () => vaultLocator.setVaultPath('/docs/ancien_vault'),
      ]);
    });

    test('does not roll back the vault path on the happy path', () async {
      stubHappyPath();

      await repository.configureWithRemote(remoteUrl: remoteUrl, token: token);

      verifyNever(() => vaultLocator.clearVaultPath());
      verify(() => vaultLocator.setVaultPath(vaultPath)).called(1);
    });

    test(
      'converts a GitException from token storage into SyncFailure',
      () async {
        when(
          () => localDataSource.storeToken(any()),
        ).thenThrow(const GitException('coffre-fort indisponible'));

        final result = await repository.configureWithRemote(
          remoteUrl: remoteUrl,
          token: token,
        );

        expect(
          result,
          const Left<Failure, VaultConfig>(
            SyncFailure('coffre-fort indisponible'),
          ),
        );
        verifyZeroInteractions(gitSyncRepository);
      },
    );
  });

  group('configureLocalOnly', () {
    void stubHappyPath() {
      when(
        () => localDataSource.defaultVaultPath(),
      ).thenAnswer((_) async => vaultPath);
      when(
        () => localDataSource.createVaultDirectory(any()),
      ).thenAnswer((_) async {});
      when(() => vaultLocator.setVaultPath(any())).thenAnswer((_) async {});
      when(
        () => gitSyncRepository.initLocal(),
      ).thenAnswer((_) async => Right(unit));
      when(
        () => localDataSource.createLocalVaultStructure(any()),
      ).thenAnswer((_) async {});
      when(() => localDataSource.saveConfig(any())).thenAnswer((_) async {});
    }

    test(
      'creates the folder, inits git and persists a remote-less config',
      () async {
        stubHappyPath();

        final result = await repository.configureLocalOnly();

        expect(
          result,
          const Right<Failure, VaultConfig>(
            VaultConfigModel(vaultPath: vaultPath),
          ),
        );
        result.fold(
          (_) => fail('expected a config'),
          (config) => expect(config.hasRemote, isFalse),
        );
        verifyInOrder([
          () => localDataSource.createVaultDirectory(vaultPath),
          () => vaultLocator.setVaultPath(vaultPath),
          () => gitSyncRepository.initLocal(),
          () => localDataSource.createLocalVaultStructure(vaultPath),
          () => localDataSource.saveConfig(
            const VaultConfigModel(vaultPath: vaultPath),
          ),
        ]);
      },
    );

    test('propagates an initLocal failure and stops there', () async {
      stubHappyPath();
      when(
        () => gitSyncRepository.initLocal(),
      ).thenAnswer((_) async => const Left(SyncFailure('init impossible')));

      final result = await repository.configureLocalOnly();

      expect(
        result,
        const Left<Failure, VaultConfig>(SyncFailure('init impossible')),
      );
      verifyNever(() => localDataSource.createLocalVaultStructure(any()));
      verifyNever(() => localDataSource.saveConfig(any()));
    });

    test('converts a VaultException into VaultFailure', () async {
      stubHappyPath();
      when(
        () => localDataSource.createVaultDirectory(any()),
      ).thenThrow(const VaultException('disque plein'));

      final result = await repository.configureLocalOnly();

      expect(
        result,
        const Left<Failure, VaultConfig>(VaultFailure('disque plein')),
      );
      verifyZeroInteractions(gitSyncRepository);
    });
  });
}
