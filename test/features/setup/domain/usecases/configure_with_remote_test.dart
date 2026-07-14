import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/setup/domain/entities/vault_config.dart';
import 'package:second_brain/features/setup/domain/repositories/setup_repository.dart';
import 'package:second_brain/features/setup/domain/usecases/configure_with_remote.dart';

class MockSetupRepository extends Mock implements SetupRepository {}

void main() {
  late MockSetupRepository repository;
  late ConfigureWithRemote usecase;

  setUp(() {
    repository = MockSetupRepository();
    usecase = ConfigureWithRemote(repository);
  });

  test('delegates to the repository with a trimmed url', () async {
    const config = VaultConfig(
      vaultPath: '/docs/second_brain_vault',
      remoteUrl: 'https://github.com/user/notes.git',
    );
    when(
      () => repository.configureWithRemote(
        remoteUrl: any(named: 'remoteUrl'),
        token: any(named: 'token'),
      ),
    ).thenAnswer((_) async => const Right(config));

    final result = await usecase(
      const ConfigureWithRemoteParams(
        remoteUrl: '  https://github.com/user/notes.git  ',
        token: 'ghp_token123',
      ),
    );

    expect(result, const Right<Failure, VaultConfig>(config));
    verify(
      () => repository.configureWithRemote(
        remoteUrl: 'https://github.com/user/notes.git',
        token: 'ghp_token123',
      ),
    ).called(1);
  });

  test('rejects an invalid url without touching the repository', () async {
    final result = await usecase(
      const ConfigureWithRemoteParams(remoteUrl: 'not-a-url', token: 't'),
    );

    expect(
      result,
      const Left<Failure, VaultConfig>(
        ValidationFailure('URL de dépôt invalide'),
      ),
    );
    verifyZeroInteractions(repository);
  });
}
