import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/sync/domain/repositories/git_sync_repository.dart';
import 'package:second_brain/features/sync/domain/usecases/test_remote_connection.dart';

class MockGitSyncRepository extends Mock implements GitSyncRepository {}

void main() {
  late MockGitSyncRepository repository;
  late TestRemoteConnection useCase;

  setUp(() {
    repository = MockGitSyncRepository();
    useCase = TestRemoteConnection(repository);
  });

  test('tests the connection with the candidate token', () async {
    when(
      () => repository.testRemoteConnection(tokenOverride: 'candidate'),
    ).thenAnswer((_) async => const Right(unit));

    final result = await useCase(
      const TestRemoteConnectionParams(tokenOverride: 'candidate'),
    );

    expect(result, const Right<Failure, Unit>(unit));
    verify(
      () => repository.testRemoteConnection(tokenOverride: 'candidate'),
    ).called(1);
  });

  test('tests the stored token when no candidate is given', () async {
    when(
      () => repository.testRemoteConnection(),
    ).thenAnswer((_) async => const Right(unit));

    final result = await useCase(const TestRemoteConnectionParams());

    expect(result, const Right<Failure, Unit>(unit));
    verify(() => repository.testRemoteConnection()).called(1);
  });

  test('propagates the repository failure', () async {
    when(
      () => repository.testRemoteConnection(tokenOverride: 'bad'),
    ).thenAnswer(
      (_) async => const Left(SyncFailure('Jeton refusé par le dépôt distant')),
    );

    final result = await useCase(
      const TestRemoteConnectionParams(tokenOverride: 'bad'),
    );

    expect(
      result,
      const Left<Failure, Unit>(
        SyncFailure('Jeton refusé par le dépôt distant'),
      ),
    );
  });
}
