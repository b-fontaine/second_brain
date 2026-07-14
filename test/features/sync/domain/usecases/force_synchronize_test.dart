import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/sync/domain/repositories/git_sync_repository.dart';
import 'package:second_brain/features/sync/domain/usecases/force_synchronize.dart';

class MockGitSyncRepository extends Mock implements GitSyncRepository {}

void main() {
  late MockGitSyncRepository repository;
  late ForceSynchronize useCase;

  setUp(() {
    repository = MockGitSyncRepository();
    useCase = ForceSynchronize(repository);
  });

  test('commits pending changes then synchronizes', () async {
    when(
      () => repository.commitAll(any()),
    ).thenAnswer((_) async => const Right(unit));
    when(
      () => repository.synchronize(),
    ).thenAnswer((_) async => const Right(unit));

    final result = await useCase(const NoParams());

    expect(result, const Right<Failure, Unit>(unit));
    verifyInOrder([
      () => repository.commitAll('note: sauvegarde manuelle'),
      () => repository.synchronize(),
    ]);
  });

  test('returns the commit failure without synchronizing', () async {
    when(
      () => repository.commitAll(any()),
    ).thenAnswer((_) async => const Left(SyncFailure('disque plein')));

    final result = await useCase(const NoParams());

    expect(result, const Left<Failure, Unit>(SyncFailure('disque plein')));
    verifyNever(() => repository.synchronize());
  });

  test('propagates a synchronize failure', () async {
    when(
      () => repository.commitAll(any()),
    ).thenAnswer((_) async => const Right(unit));
    when(
      () => repository.synchronize(),
    ).thenAnswer((_) async => const Left(OfflineFailure()));

    final result = await useCase(const NoParams());

    expect(result, const Left<Failure, Unit>(OfflineFailure()));
  });
}
