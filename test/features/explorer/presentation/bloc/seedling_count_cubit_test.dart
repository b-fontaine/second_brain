import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/services/vault_write_notifier.dart';
import 'package:second_brain/features/explorer/presentation/bloc/seedling_count_cubit.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/repositories/inbox_repository.dart';

/// Controllable in-memory stand-in: the cubit only calls [getPendingItems].
class _StubInboxRepository implements InboxRepository {
  Either<Failure, List<InboxItem>> pendingResult = const Right([]);

  @override
  Future<Either<Failure, List<InboxItem>>> getPendingItems() async =>
      pendingResult;

  @override
  Future<Either<Failure, InboxItem>> addItem(InboxItem item) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, InboxItem>> updateItem(InboxItem item) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeItem(String id) =>
      throw UnimplementedError();
}

InboxItem _item(String id) => InboxItem(
  id: id,
  type: CaptureType.clipboard,
  rawText: 'capture $id',
  capturedAt: DateTime(2026, 6, 1, 9),
);

void main() {
  late _StubInboxRepository repository;
  late VaultWriteNotifier notifier;
  late SeedlingCountCubit cubit;

  setUp(() {
    repository = _StubInboxRepository();
    notifier = VaultWriteNotifier();
    cubit = SeedlingCountCubit(repository, notifier);
  });

  tearDown(() async {
    await cubit.close();
    await notifier.dispose();
  });

  test('starts at zero before start()', () {
    expect(cubit.state, 0);
  });

  test('start() loads the pending capture count', () async {
    repository.pendingResult = Right([_item('a'), _item('b')]);

    await cubit.start();

    expect(cubit.state, 2);
  });

  test('reloads the count on every vault write pulse', () async {
    repository.pendingResult = Right([_item('a')]);
    await cubit.start();
    expect(cubit.state, 1);

    repository.pendingResult = Right([_item('a'), _item('b'), _item('c')]);
    notifier.notifyWrite();
    // Let the stream event and the async reload run.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, 3);
  });

  test('a read failure keeps the last known count', () async {
    repository.pendingResult = Right([_item('a'), _item('b')]);
    await cubit.start();
    expect(cubit.state, 2);

    repository.pendingResult = const Left(VaultFailure('disque en feu'));
    notifier.notifyWrite();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, 2);
  });

  test('ignores pulses after close', () async {
    repository.pendingResult = Right([_item('a')]);
    await cubit.start();
    await cubit.close();

    repository.pendingResult = Right([_item('a'), _item('b')]);
    notifier.notifyWrite();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, 1);
  });
}
