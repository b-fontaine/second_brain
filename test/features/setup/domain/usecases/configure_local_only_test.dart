import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/setup/domain/entities/vault_config.dart';
import 'package:second_brain/features/setup/domain/repositories/setup_repository.dart';
import 'package:second_brain/features/setup/domain/usecases/configure_local_only.dart';

class MockSetupRepository extends Mock implements SetupRepository {}

void main() {
  late MockSetupRepository repository;
  late ConfigureLocalOnly usecase;

  setUp(() {
    repository = MockSetupRepository();
    usecase = ConfigureLocalOnly(repository);
  });

  test('delegates to the repository', () async {
    const config = VaultConfig(vaultPath: '/docs/second_brain_vault');
    when(
      () => repository.configureLocalOnly(),
    ).thenAnswer((_) async => const Right(config));

    final result = await usecase(const NoParams());

    expect(result, const Right<Failure, VaultConfig>(config));
    verify(() => repository.configureLocalOnly()).called(1);
  });

  test('propagates failures', () async {
    when(() => repository.configureLocalOnly()).thenAnswer(
      (_) async => const Left(VaultFailure('Impossible de créer le dossier')),
    );

    final result = await usecase(const NoParams());

    expect(
      result,
      const Left<Failure, VaultConfig>(
        VaultFailure('Impossible de créer le dossier'),
      ),
    );
  });
}
