import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/services/vault_write_notifier.dart';
import 'package:second_brain/features/capture/presentation/bloc/pepiniere_cubit.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/inbox_repository.dart';
import 'package:second_brain/features/zettel/domain/usecases/transplant_seedling.dart';

class MockInboxRepository extends Mock implements InboxRepository {}

class MockTransplantSeedling extends Mock implements TransplantSeedling {}

void main() {
  late MockInboxRepository inboxRepository;
  late MockTransplantSeedling transplantSeedling;
  late VaultWriteNotifier vaultWriteNotifier;

  final itemA = InboxItem(
    id: '20260716094100',
    type: CaptureType.clipboard,
    rawText: 'Premier semis en attente.',
    capturedAt: DateTime(2026, 7, 16, 9, 41),
    title: 'Premier semis',
    tags: const ['jardin'],
  );
  final itemB = InboxItem(
    id: '20260716101500',
    type: CaptureType.dictation,
    rawText: 'Second semis en attente.',
    capturedAt: DateTime(2026, 7, 16, 10, 15),
  );
  final tZettel = Zettel(
    id: ZettelId.fromString('20260716110000'),
    title: 'Premier semis',
    body: 'Premier semis en attente.',
    createdAt: DateTime(2026, 7, 16, 11),
  );

  setUpAll(() {
    registerFallbackValue(TransplantSeedlingParams(item: itemA));
  });

  setUp(() {
    inboxRepository = MockInboxRepository();
    transplantSeedling = MockTransplantSeedling();
    vaultWriteNotifier = VaultWriteNotifier();
    when(
      () => inboxRepository.getPendingItems(),
    ).thenAnswer((_) async => Right([itemA, itemB]));
  });

  tearDown(() => vaultWriteNotifier.dispose());

  PepiniereCubit buildCubit() =>
      PepiniereCubit(inboxRepository, transplantSeedling, vaultWriteNotifier);

  group('start', () {
    blocTest<PepiniereCubit, PepiniereState>(
      'loads the pending queue',
      build: buildCubit,
      act: (cubit) => cubit.start(),
      expect: () => [
        PepiniereLoaded(items: [itemA, itemB]),
      ],
    );

    blocTest<PepiniereCubit, PepiniereState>(
      'surfaces a first-load failure',
      setUp: () {
        when(
          () => inboxRepository.getPendingItems(),
        ).thenAnswer((_) async => const Left(VaultFailure('coffre illisible')));
      },
      build: buildCubit,
      act: (cubit) => cubit.start(),
      expect: () => [const PepiniereLoadFailure('coffre illisible')],
    );

    blocTest<PepiniereCubit, PepiniereState>(
      'reloads on every vault write pulse',
      build: buildCubit,
      act: (cubit) async {
        await cubit.start();
        when(
          () => inboxRepository.getPendingItems(),
        ).thenAnswer((_) async => Right([itemA]));
        vaultWriteNotifier.notifyWrite();
        // Let the stream listener run its async reload.
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        PepiniereLoaded(items: [itemA, itemB]),
        PepiniereLoaded(items: [itemA]),
      ],
    );

    blocTest<PepiniereCubit, PepiniereState>(
      'a reload failure keeps the last known list (offline-first)',
      build: buildCubit,
      act: (cubit) async {
        await cubit.start();
        when(
          () => inboxRepository.getPendingItems(),
        ).thenAnswer((_) async => const Left(VaultFailure('transitoire')));
        vaultWriteNotifier.notifyWrite();
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        PepiniereLoaded(items: [itemA, itemB]),
      ],
    );
  });

  group('transplant', () {
    blocTest<PepiniereCubit, PepiniereState>(
      'marks the card busy, removes it on success and notices',
      setUp: () {
        when(
          () => transplantSeedling(any()),
        ).thenAnswer((_) async => Right(tZettel));
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.start();
        await cubit.transplant(itemA);
      },
      expect: () => [
        PepiniereLoaded(items: [itemA, itemB]),
        PepiniereLoaded(items: [itemA, itemB], busyItemId: itemA.id),
        PepiniereLoaded(
          items: [itemB],
          notice: const PepiniereNotice(
            1,
            'Repiqué au jardin — note « Premier semis » créée.',
          ),
        ),
      ],
      verify: (_) {
        verify(
          () => transplantSeedling(TransplantSeedlingParams(item: itemA)),
        ).called(1);
      },
    );

    blocTest<PepiniereCubit, PepiniereState>(
      'keeps the card with an error notice on failure',
      setUp: () {
        when(
          () => transplantSeedling(any()),
        ).thenAnswer((_) async => const Left(VaultFailure('disque plein')));
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.start();
        await cubit.transplant(itemA);
      },
      expect: () => [
        PepiniereLoaded(items: [itemA, itemB]),
        PepiniereLoaded(items: [itemA, itemB], busyItemId: itemA.id),
        PepiniereLoaded(
          items: [itemA, itemB],
          notice: const PepiniereNotice(
            1,
            'Le repiquage a échoué : disque plein',
          ),
        ),
      ],
    );

    blocTest<PepiniereCubit, PepiniereState>(
      'refuses a second action while one is in flight',
      setUp: () {
        when(() => transplantSeedling(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return Right(tZettel);
        });
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.start();
        final first = cubit.transplant(itemA);
        await cubit.transplant(itemB); // Ignored: itemA is busy.
        await first;
      },
      verify: (_) {
        verify(() => transplantSeedling(any())).called(1);
      },
    );
  });

  group('compost', () {
    blocTest<PepiniereCubit, PepiniereState>(
      'removes the item and notices',
      setUp: () {
        when(
          () => inboxRepository.removeItem(itemB.id),
        ).thenAnswer((_) async => const Right(unit));
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.start();
        await cubit.compost(itemB);
      },
      expect: () => [
        PepiniereLoaded(items: [itemA, itemB]),
        PepiniereLoaded(items: [itemA, itemB], busyItemId: itemB.id),
        PepiniereLoaded(
          items: [itemA],
          notice: const PepiniereNotice(
            1,
            'Semis composté — brouillon supprimé.',
          ),
        ),
      ],
      verify: (_) {
        verify(() => inboxRepository.removeItem(itemB.id)).called(1);
        verifyNever(() => transplantSeedling(any()));
      },
    );

    blocTest<PepiniereCubit, PepiniereState>(
      'keeps the card with an error notice on failure',
      setUp: () {
        when(
          () => inboxRepository.removeItem(itemB.id),
        ).thenAnswer((_) async => const Left(VaultFailure('verrouillé')));
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.start();
        await cubit.compost(itemB);
      },
      expect: () => [
        PepiniereLoaded(items: [itemA, itemB]),
        PepiniereLoaded(items: [itemA, itemB], busyItemId: itemB.id),
        PepiniereLoaded(
          items: [itemA, itemB],
          notice: const PepiniereNotice(
            1,
            'Le compostage a échoué : verrouillé',
          ),
        ),
      ],
    );
  });
}
