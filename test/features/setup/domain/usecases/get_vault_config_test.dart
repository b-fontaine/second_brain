import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/setup/domain/entities/vault_config.dart';
import 'package:second_brain/features/setup/domain/repositories/setup_repository.dart';
import 'package:second_brain/features/setup/domain/usecases/get_vault_config.dart';

class MockSetupRepository extends Mock implements SetupRepository {}

void main() {
  late MockSetupRepository repository;
  late GetVaultConfig usecase;

  setUp(() {
    repository = MockSetupRepository();
    usecase = GetVaultConfig(repository);
  });

  test('returns null on first run', () async {
    when(
      () => repository.getConfig(),
    ).thenAnswer((_) async => const Right(null));

    final result = await usecase(const NoParams());

    expect(result, const Right<Failure, VaultConfig?>(null));
    verify(() => repository.getConfig()).called(1);
  });

  test('returns the persisted config', () async {
    const config = VaultConfig(
      vaultPath: '/docs/second_brain_vault',
      remoteUrl: 'https://github.com/user/notes.git',
    );
    when(
      () => repository.getConfig(),
    ).thenAnswer((_) async => const Right(config));

    final result = await usecase(const NoParams());

    expect(result, const Right<Failure, VaultConfig?>(config));
  });
}
