import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/services/network_info.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/sync/domain/entities/sync_status.dart';
import 'package:second_brain/features/sync/domain/usecases/force_synchronize.dart';
import 'package:second_brain/features/sync/domain/usecases/get_sync_status.dart';
import 'package:second_brain/features/sync/domain/usecases/watch_sync_status.dart';
import 'package:second_brain/features/sync/presentation/bloc/sync_status_cubit.dart';

class MockGetSyncStatus extends Mock implements GetSyncStatus {}

class MockWatchSyncStatus extends Mock implements WatchSyncStatus {}

class MockForceSynchronize extends Mock implements ForceSynchronize {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  const upToDate = SyncStatus(state: SyncState.upToDate);
  const syncing = SyncStatus(state: SyncState.syncing);

  late MockGetSyncStatus getSyncStatus;
  late MockWatchSyncStatus watchSyncStatus;
  late MockForceSynchronize forceSynchronize;
  late MockNetworkInfo networkInfo;
  late StreamController<Either<Failure, SyncStatus>> statusController;
  late StreamController<bool> networkController;

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    getSyncStatus = MockGetSyncStatus();
    watchSyncStatus = MockWatchSyncStatus();
    forceSynchronize = MockForceSynchronize();
    networkInfo = MockNetworkInfo();
    statusController = StreamController<Either<Failure, SyncStatus>>();
    networkController = StreamController<bool>();

    when(
      () => getSyncStatus(any()),
    ).thenAnswer((_) async => const Right(upToDate));
    when(
      () => watchSyncStatus(any()),
    ).thenAnswer((_) => statusController.stream);
    when(
      () => forceSynchronize(any()),
    ).thenAnswer((_) async => const Right(unit));
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    when(
      () => networkInfo.onStatusChange,
    ).thenAnswer((_) => networkController.stream);
  });

  tearDown(() async {
    await statusController.close();
    await networkController.close();
  });

  SyncStatusCubit buildCubit() => SyncStatusCubit(
    getSyncStatus,
    watchSyncStatus,
    forceSynchronize,
    networkInfo,
  );

  blocTest<SyncStatusCubit, SyncStatusState>(
    'emits the initial status then every stream update',
    build: buildCubit,
    act: (cubit) async {
      await cubit.start();
      statusController.add(const Right(syncing));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => const [
      SyncStatusReady(status: upToDate, isOnline: true),
      SyncStatusReady(status: syncing, isOnline: true),
    ],
  );

  blocTest<SyncStatusCubit, SyncStatusState>(
    'emits an error status when the initial load fails',
    build: buildCubit,
    setUp: () {
      when(
        () => getSyncStatus(any()),
      ).thenAnswer((_) async => const Left(SyncFailure('dépôt corrompu')));
    },
    act: (cubit) => cubit.start(),
    expect: () => const [
      SyncStatusReady(
        status: SyncStatus(state: SyncState.error, message: 'dépôt corrompu'),
        isOnline: true,
      ),
    ],
  );

  blocTest<SyncStatusCubit, SyncStatusState>(
    're-emits with the new connectivity when it changes',
    build: buildCubit,
    act: (cubit) async {
      await cubit.start();
      networkController.add(false);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => const [
      SyncStatusReady(status: upToDate, isOnline: true),
      SyncStatusReady(status: upToDate, isOnline: false),
    ],
  );

  blocTest<SyncStatusCubit, SyncStatusState>(
    'forceSync delegates to the ForceSynchronize use case',
    build: buildCubit,
    act: (cubit) async {
      await cubit.start();
      await cubit.forceSync();
    },
    verify: (_) {
      verify(() => forceSynchronize(any())).called(1);
    },
  );

  blocTest<SyncStatusCubit, SyncStatusState>(
    'forceSync is ignored while a synchronization is already running',
    build: buildCubit,
    act: (cubit) async {
      await cubit.start();
      statusController.add(const Right(syncing));
      await Future<void>.delayed(Duration.zero);
      await cubit.forceSync();
    },
    verify: (_) {
      verifyNever(() => forceSynchronize(any()));
    },
  );
}
