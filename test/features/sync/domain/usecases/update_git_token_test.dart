import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/sync/domain/repositories/git_sync_repository.dart';
import 'package:second_brain/features/sync/domain/usecases/update_git_token.dart';

class MockGitSyncRepository extends Mock implements GitSyncRepository {}

void main() {
  late MockGitSyncRepository repository;
  late UpdateGitToken useCase;

  setUp(() {
    repository = MockGitSyncRepository();
    useCase = UpdateGitToken(repository);
  });

  test('delegates the token update to the repository', () async {
    when(
      () => repository.updateToken('new-token'),
    ).thenAnswer((_) async => const Right(unit));

    final result = await useCase(const UpdateGitTokenParams('new-token'));

    expect(result, const Right<Failure, Unit>(unit));
    verify(() => repository.updateToken('new-token')).called(1);
  });

  test('propagates the repository failure', () async {
    when(() => repository.updateToken('bad-token')).thenAnswer(
      (_) async => const Left(SyncFailure('Jeton refusé par le dépôt distant')),
    );

    final result = await useCase(const UpdateGitTokenParams('bad-token'));

    expect(
      result,
      const Left<Failure, Unit>(
        SyncFailure('Jeton refusé par le dépôt distant'),
      ),
    );
  });
}
