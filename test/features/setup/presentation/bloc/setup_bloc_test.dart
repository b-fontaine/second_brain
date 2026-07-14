import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/setup/domain/entities/vault_config.dart';
import 'package:second_brain/features/setup/domain/usecases/configure_local_only.dart';
import 'package:second_brain/features/setup/domain/usecases/configure_with_remote.dart';
import 'package:second_brain/features/setup/presentation/bloc/setup_bloc.dart';

class MockConfigureWithRemote extends Mock implements ConfigureWithRemote {}

class MockConfigureLocalOnly extends Mock implements ConfigureLocalOnly {}

void main() {
  late MockConfigureWithRemote configureWithRemote;
  late MockConfigureLocalOnly configureLocalOnly;

  const remoteUrl = 'https://github.com/user/zettelkasten.git';
  const token = 'ghp_token123';
  const remoteConfig = VaultConfig(
    vaultPath: '/docs/second_brain_vault',
    remoteUrl: remoteUrl,
  );
  const localConfig = VaultConfig(vaultPath: '/docs/second_brain_vault');

  setUpAll(() {
    registerFallbackValue(
      const ConfigureWithRemoteParams(remoteUrl: '', token: ''),
    );
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    configureWithRemote = MockConfigureWithRemote();
    configureLocalOnly = MockConfigureLocalOnly();
  });

  SetupBloc buildBloc() => SetupBloc(configureWithRemote, configureLocalOnly);

  test('initial state is SetupInitial', () {
    expect(buildBloc().state, const SetupInitial());
  });

  group('SetupRemoteSubmitted', () {
    blocTest<SetupBloc, SetupState>(
      'emits [validating, cloning, done] on successful clone',
      setUp: () {
        when(
          () => configureWithRemote(any()),
        ).thenAnswer((_) async => const Right(remoteConfig));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        SetupRemoteSubmitted(remoteUrl: ' $remoteUrl ', token: token),
      ),
      expect: () => const [
        SetupValidating(),
        SetupCloning(),
        SetupDone(remoteConfig),
      ],
      verify: (_) {
        verify(
          () => configureWithRemote(
            const ConfigureWithRemoteParams(remoteUrl: remoteUrl, token: token),
          ),
        ).called(1);
      },
    );

    blocTest<SetupBloc, SetupState>(
      'emits [validating, error] with the exact message on an invalid url, '
      'without calling the use case',
      build: buildBloc,
      act: (bloc) => bloc.add(
        const SetupRemoteSubmitted(remoteUrl: 'not-a-url', token: token),
      ),
      expect: () => const [
        SetupValidating(),
        SetupError('URL de dépôt invalide'),
      ],
      verify: (_) {
        verifyZeroInteractions(configureWithRemote);
      },
    );

    blocTest<SetupBloc, SetupState>(
      'emits [validating, cloning, error] when the clone fails',
      setUp: () {
        when(() => configureWithRemote(any())).thenAnswer(
          (_) async => const Left(
            SyncFailure('Échec du clonage : authentification refusée'),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const SetupRemoteSubmitted(remoteUrl: remoteUrl, token: token),
      ),
      expect: () => const [
        SetupValidating(),
        SetupCloning(),
        SetupError('Échec du clonage : authentification refusée'),
      ],
    );
  });

  group('SetupLocalOnlyRequested', () {
    blocTest<SetupBloc, SetupState>(
      'emits [validating, done] when the local vault is created',
      setUp: () {
        when(
          () => configureLocalOnly(any()),
        ).thenAnswer((_) async => const Right(localConfig));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SetupLocalOnlyRequested()),
      expect: () => const [SetupValidating(), SetupDone(localConfig)],
    );

    blocTest<SetupBloc, SetupState>(
      'emits [validating, error] when the local vault creation fails',
      setUp: () {
        when(() => configureLocalOnly(any())).thenAnswer(
          (_) async => const Left(
            VaultFailure('Impossible de créer le dossier du coffre'),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SetupLocalOnlyRequested()),
      expect: () => const [
        SetupValidating(),
        SetupError('Impossible de créer le dossier du coffre'),
      ],
    );
  });
}
