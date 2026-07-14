import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/usecases/delete_zettel.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_backlinks.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_zettel_by_id.dart';
import 'package:second_brain/features/zettel/presentation/bloc/zettel_detail/zettel_detail_cubit.dart';

class MockGetZettelById extends Mock implements GetZettelById {}

class MockGetBacklinks extends Mock implements GetBacklinks {}

class MockDeleteZettel extends Mock implements DeleteZettel {}

void main() {
  final noteId = ZettelId.fromString('20260101120000');
  final linkedId = ZettelId.fromString('20260202120000');

  final note = Zettel(
    id: noteId,
    title: 'Concept A',
    body: 'Voir [[20260202120000]] pour approfondir.',
    createdAt: DateTime(2026, 1, 1, 12),
    tags: const ['cognition'],
  );
  final linkedNote = Zettel(
    id: linkedId,
    title: 'Concept B',
    body: 'Corps B.',
    createdAt: DateTime(2026, 2, 2, 12),
  );
  final backlink = Zettel(
    id: ZettelId.fromString('20260303120000'),
    title: 'Concept C',
    body: 'Référence [[20260101120000]].',
    createdAt: DateTime(2026, 3, 3, 12),
  );

  late MockGetZettelById getZettelById;
  late MockGetBacklinks getBacklinks;
  late MockDeleteZettel deleteZettel;

  setUpAll(() {
    registerFallbackValue(ZettelId.fromString('20260101120000'));
  });

  setUp(() {
    getZettelById = MockGetZettelById();
    getBacklinks = MockGetBacklinks();
    deleteZettel = MockDeleteZettel();
  });

  ZettelDetailCubit buildCubit() =>
      ZettelDetailCubit(getZettelById, getBacklinks, deleteZettel);

  group('ZettelDetailCubit', () {
    test('initial state is ZettelDetailInitial', () {
      expect(buildCubit().state, const ZettelDetailInitial());
    });

    blocTest<ZettelDetailCubit, ZettelDetailState>(
      'emits [loading, loaded] with backlinks and resolved link titles',
      setUp: () {
        when(() => getZettelById(noteId)).thenAnswer((_) async => Right(note));
        when(
          () => getZettelById(linkedId),
        ).thenAnswer((_) async => Right(linkedNote));
        when(
          () => getBacklinks(noteId),
        ).thenAnswer((_) async => Right([backlink]));
      },
      build: buildCubit,
      act: (cubit) => cubit.load(noteId),
      expect: () => [
        const ZettelDetailLoading(),
        ZettelDetailLoaded(
          zettel: note,
          backlinks: [backlink],
          linkTitles: const {'20260202120000': 'Concept B'},
        ),
      ],
    );

    blocTest<ZettelDetailCubit, ZettelDetailState>(
      'emits [loading, error] when the zettel cannot be loaded',
      setUp: () {
        when(
          () => getZettelById(noteId),
        ).thenAnswer((_) async => Left(ZettelNotFoundFailure(noteId.value)));
      },
      build: buildCubit,
      act: (cubit) => cubit.load(noteId),
      expect: () => [
        const ZettelDetailLoading(),
        ZettelDetailError('Note introuvable : ${noteId.value}'),
      ],
    );

    blocTest<ZettelDetailCubit, ZettelDetailState>(
      'still loads the note when backlinks fail (empty backlinks)',
      setUp: () {
        when(() => getZettelById(noteId)).thenAnswer((_) async => Right(note));
        when(
          () => getZettelById(linkedId),
        ).thenAnswer((_) async => Left(ZettelNotFoundFailure(linkedId.value)));
        when(() => getBacklinks(noteId)).thenAnswer(
          (_) async => const Left(VaultFailure('Index indisponible')),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.load(noteId),
      expect: () => [
        const ZettelDetailLoading(),
        ZettelDetailLoaded(
          zettel: note,
          backlinks: const [],
          linkTitles: const {},
        ),
      ],
    );

    blocTest<ZettelDetailCubit, ZettelDetailState>(
      'emits ZettelDetailDeleted when deletion succeeds',
      setUp: () {
        when(
          () => deleteZettel(noteId),
        ).thenAnswer((_) async => const Right(unit));
      },
      build: buildCubit,
      seed: () => ZettelDetailLoaded(zettel: note),
      act: (cubit) => cubit.delete(),
      expect: () => [const ZettelDetailDeleted()],
    );

    blocTest<ZettelDetailCubit, ZettelDetailState>(
      'keeps the loaded state with an error message when deletion fails',
      setUp: () {
        when(() => deleteZettel(noteId)).thenAnswer(
          (_) async => const Left(VaultFailure('Suppression impossible')),
        );
      },
      build: buildCubit,
      seed: () => ZettelDetailLoaded(zettel: note),
      act: (cubit) => cubit.delete(),
      expect: () => [
        ZettelDetailLoaded(
          zettel: note,
          errorMessage: 'Suppression impossible',
        ),
      ],
    );

    blocTest<ZettelDetailCubit, ZettelDetailState>(
      'does nothing on delete when no zettel is loaded',
      build: buildCubit,
      act: (cubit) => cubit.delete(),
      expect: () => const <ZettelDetailState>[],
      verify: (_) {
        verifyNever(() => deleteZettel(any()));
      },
    );
  });
}
