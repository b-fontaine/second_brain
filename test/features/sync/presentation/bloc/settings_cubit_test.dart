import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/setup/domain/entities/vault_config.dart';
import 'package:second_brain/features/setup/domain/usecases/get_vault_config.dart';
import 'package:second_brain/features/sync/domain/entities/sync_status.dart';
import 'package:second_brain/features/sync/domain/repositories/git_sync_repository.dart';
import 'package:second_brain/features/sync/domain/usecases/force_synchronize.dart';
import 'package:second_brain/features/sync/domain/usecases/get_sync_status.dart';
import 'package:second_brain/features/sync/domain/usecases/test_remote_connection.dart';
import 'package:second_brain/features/sync/domain/usecases/update_git_token.dart';
import 'package:second_brain/features/sync/presentation/bloc/settings_cubit.dart';

class MockGetVaultConfig extends Mock implements GetVaultConfig {}

class MockGetSyncStatus extends Mock implements GetSyncStatus {}

class MockTestRemoteConnection extends Mock implements TestRemoteConnection {}

class MockUpdateGitToken extends Mock implements UpdateGitToken {}

class MockForceSynchronize extends Mock implements ForceSynchronize {}

class MockGitSyncRepository extends Mock implements GitSyncRepository {}

void main() {
  const remoteUrl = 'https://github.com/user/notes.git';
  const upToDate = SyncStatus(state: SyncState.upToDate);
  const loaded = SettingsLoaded(
    remoteUrl: remoteUrl,
    hasStoredToken: false,
    syncStatus: upToDate,
  );

  late MockGetVaultConfig getVaultConfig;
  late MockGetSyncStatus getSyncStatus;
  late MockTestRemoteConnection testRemoteConnection;
  late MockUpdateGitToken updateGitToken;
  late MockForceSynchronize forceSynchronize;
  late MockGitSyncRepository repository;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const TestRemoteConnectionParams());
    registerFallbackValue(const UpdateGitTokenParams(''));
  });

  setUp(() {
    getVaultConfig = MockGetVaultConfig();
    getSyncStatus = MockGetSyncStatus();
    testRemoteConnection = MockTestRemoteConnection();
    updateGitToken = MockUpdateGitToken();
    forceSynchronize = MockForceSynchronize();
    repository = MockGitSyncRepository();

    when(() => getVaultConfig(any())).thenAnswer(
      (_) async =>
          const Right(VaultConfig(vaultPath: '/vault', remoteUrl: remoteUrl)),
    );
    when(
      () => repository.hasStoredToken(),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => getSyncStatus(any()),
    ).thenAnswer((_) async => const Right(upToDate));
    when(
      () => testRemoteConnection(any()),
    ).thenAnswer((_) async => const Right(unit));
    when(() => updateGitToken(any())).thenAnswer((_) async => const Right(unit));
    when(
      () => forceSynchronize(any()),
    ).thenAnswer((_) async => const Right(unit));
  });

  SettingsCubit buildCubit() => SettingsCubit(
    getVaultConfig,
    getSyncStatus,
    testRemoteConnection,
    updateGitToken,
    forceSynchronize,
    repository,
  );

  group('load', () {
    blocTest<SettingsCubit, SettingsState>(
      'emits the remote url, token presence and sync status',
      build: buildCubit,
      setUp: () {
        when(
          () => repository.hasStoredToken(),
        ).thenAnswer((_) async => const Right(true));
      },
      act: (cubit) => cubit.load(),
      expect: () => const [
        SettingsLoading(),
        SettingsLoaded(
          remoteUrl: remoteUrl,
          hasStoredToken: true,
          syncStatus: upToDate,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'reports a local-only vault (no remote url, no token)',
      build: buildCubit,
      setUp: () {
        when(() => getVaultConfig(any())).thenAnswer(
          (_) async => const Right(VaultConfig(vaultPath: '/vault')),
        );
      },
      act: (cubit) => cubit.load(),
      expect: () => const [
        SettingsLoading(),
        SettingsLoaded(
          remoteUrl: null,
          hasStoredToken: false,
          syncStatus: upToDate,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'emits an error when the configuration cannot be read',
      build: buildCubit,
      setUp: () {
        when(() => getVaultConfig(any())).thenAnswer(
          (_) async => const Left(VaultFailure('lecture impossible')),
        );
      },
      act: (cubit) => cubit.load(),
      expect: () => const [
        SettingsLoading(),
        SettingsError('lecture impossible'),
      ],
    );
  });

  group('testConnection', () {
    blocTest<SettingsCubit, SettingsState>(
      'tests the trimmed candidate token and reports success',
      build: buildCubit,
      seed: () => loaded,
      act: (cubit) => cubit.testConnection('  candidate  '),
      expect: () => [SettingsTesting.of(loaded), SettingsTestSuccess.of(loaded)],
      verify: (_) {
        verify(
          () => testRemoteConnection(
            const TestRemoteConnectionParams(tokenOverride: 'candidate'),
          ),
        ).called(1);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'tests the stored token when the field is blank',
      build: buildCubit,
      seed: () => loaded,
      act: (cubit) => cubit.testConnection('   '),
      verify: (_) {
        verify(
          () => testRemoteConnection(const TestRemoteConnectionParams()),
        ).called(1);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'reports the failure message when the remote refuses the token',
      build: buildCubit,
      seed: () => loaded,
      setUp: () {
        when(() => testRemoteConnection(any())).thenAnswer(
          (_) async =>
              const Left(SyncFailure('Jeton refusé par le dépôt distant')),
        );
      },
      act: (cubit) => cubit.testConnection('bad'),
      expect: () => [
        SettingsTesting.of(loaded),
        SettingsTestFailure.of(loaded, 'Jeton refusé par le dépôt distant'),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'is ignored while a save is already running',
      build: buildCubit,
      seed: () => SettingsSaving.of(loaded),
      act: (cubit) => cubit.testConnection('candidate'),
      expect: () => const <SettingsState>[],
      verify: (_) {
        verifyNever(() => testRemoteConnection(any()));
      },
    );
  });

  group('saveToken', () {
    blocTest<SettingsCubit, SettingsState>(
      'saves atomically and reports the stored token',
      build: buildCubit,
      seed: () => loaded,
      act: (cubit) => cubit.saveToken('new-token'),
      expect: () => [SettingsSaving.of(loaded), SettingsSaved.of(loaded)],
      verify: (_) {
        verify(
          () => updateGitToken(const UpdateGitTokenParams('new-token')),
        ).called(1);
        // SettingsSaved always reports a stored token.
        expect(SettingsSaved.of(loaded).hasStoredToken, isTrue);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'keeps "no stored token" when the connection test fails (nothing '
      'persisted by contract)',
      build: buildCubit,
      seed: () => loaded,
      setUp: () {
        when(() => updateGitToken(any())).thenAnswer(
          (_) async =>
              const Left(SyncFailure('Jeton refusé par le dépôt distant')),
        );
      },
      act: (cubit) => cubit.saveToken('bad-token'),
      expect: () => [
        SettingsSaving.of(loaded),
        SettingsSaveFailure.of(loaded, 'Jeton refusé par le dépôt distant'),
      ],
      verify: (cubit) {
        final state = cubit.state as SettingsSaveFailure;
        expect(state.hasStoredToken, isFalse);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'is ignored while another save is already running',
      build: buildCubit,
      seed: () => SettingsSaving.of(loaded),
      act: (cubit) => cubit.saveToken('new-token'),
      expect: () => const <SettingsState>[],
      verify: (_) {
        verifyNever(() => updateGitToken(any()));
      },
    );
  });

  group('forceSync', () {
    blocTest<SettingsCubit, SettingsState>(
      'delegates to ForceSynchronize then refreshes the status',
      build: buildCubit,
      seed: () => loaded,
      setUp: () {
        when(() => getSyncStatus(any())).thenAnswer(
          (_) async => const Right(
            SyncStatus(state: SyncState.pendingPush, pendingCommits: 1),
          ),
        );
      },
      act: (cubit) => cubit.forceSync(),
      expect: () => const [
        SettingsLoaded(
          remoteUrl: remoteUrl,
          hasStoredToken: false,
          syncStatus: SyncStatus(
            state: SyncState.pendingPush,
            pendingCommits: 1,
          ),
        ),
      ],
      verify: (_) {
        verify(() => forceSynchronize(any())).called(1);
      },
    );
  });
}
