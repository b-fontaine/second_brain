import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/graph/domain/entities/related_note_suggestion.dart';
import 'package:second_brain/features/graph/domain/usecases/suggest_related_notes.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/usecases/delete_zettel.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_all_zettels.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_backlinks.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_zettel_by_id.dart';
import 'package:second_brain/features/zettel/domain/usecases/update_zettel.dart';
import 'package:second_brain/features/zettel/presentation/bloc/zettel_detail/zettel_detail_cubit.dart';

class MockGetZettelById extends Mock implements GetZettelById {}

class MockGetBacklinks extends Mock implements GetBacklinks {}

class MockDeleteZettel extends Mock implements DeleteZettel {}

class MockGetAllZettels extends Mock implements GetAllZettels {}

class MockUpdateZettel extends Mock implements UpdateZettel {}

class MockSuggestRelatedNotes extends Mock implements SuggestRelatedNotes {}

void main() {
  final noteId = ZettelId.fromString('20260101120000');
  final linkedId = ZettelId.fromString('20260202120000');
  final backlinkId = ZettelId.fromString('20260303120000');
  const suggestedIdValue = '20260404120000';

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
    id: backlinkId,
    title: 'Concept C',
    body: 'Référence [[20260101120000]].',
    createdAt: DateTime(2026, 3, 3, 12),
  );

  late MockGetZettelById getZettelById;
  late MockGetBacklinks getBacklinks;
  late MockDeleteZettel deleteZettel;
  late MockGetAllZettels getAllZettels;
  late MockUpdateZettel updateZettel;
  late MockSuggestRelatedNotes suggestRelatedNotes;

  setUpAll(() {
    registerFallbackValue(ZettelId.fromString('20260101120000'));
    registerFallbackValue(const NoParams());
    registerFallbackValue(const SuggestRelatedNotesParams(zettelId: ''));
    registerFallbackValue(
      Zettel(
        id: ZettelId.fromString('20260101120000'),
        title: 'fallback',
        body: '',
        createdAt: DateTime(2026),
      ),
    );
  });

  setUp(() {
    getZettelById = MockGetZettelById();
    getBacklinks = MockGetBacklinks();
    deleteZettel = MockDeleteZettel();
    getAllZettels = MockGetAllZettels();
    updateZettel = MockUpdateZettel();
    suggestRelatedNotes = MockSuggestRelatedNotes();
    // Empty suggestions by default: the Pollinisation state merge is
    // exercised explicitly where relevant.
    when(() => suggestRelatedNotes(any())).thenAnswer(
      (_) async => const Right(<RelatedNoteSuggestion>[]),
    );
  });

  ZettelDetailCubit buildCubit() => ZettelDetailCubit(
    getZettelById,
    getBacklinks,
    deleteZettel,
    getAllZettels,
    updateZettel,
    suggestRelatedNotes,
  );

  group('ZettelDetailCubit', () {
    test('initial state is ZettelDetailInitial', () {
      expect(buildCubit().state, const ZettelDetailInitial());
    });

    blocTest<ZettelDetailCubit, ZettelDetailState>(
      'emits [loading, loaded] with backlinks, resolved link titles and '
      'the degrees of the 1-hop neighborhood',
      setUp: () {
        when(() => getZettelById(noteId)).thenAnswer((_) async => Right(note));
        when(
          () => getBacklinks(noteId),
        ).thenAnswer((_) async => Right([backlink]));
        when(() => getAllZettels(any())).thenAnswer(
          (_) async => Right([note, linkedNote, backlink]),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.load(noteId),
      expect: () => [
        const ZettelDetailLoading(),
        ZettelDetailLoaded(
          zettel: note,
          backlinks: [backlink],
          linkTitles: const {'20260202120000': 'Concept B'},
          // A links to B, C links to A: degree A = 2, B = 1, C = 1.
          degrees: const {
            '20260101120000': 2,
            '20260202120000': 1,
            '20260303120000': 1,
          },
        ),
      ],
    );

    blocTest<ZettelDetailCubit, ZettelDetailState>(
      'merges the pollination suggestions once the index answers, '
      'excluding the note and its linked neighbors',
      setUp: () {
        when(() => getZettelById(noteId)).thenAnswer((_) async => Right(note));
        when(
          () => getBacklinks(noteId),
        ).thenAnswer((_) async => Right([backlink]));
        when(() => getAllZettels(any())).thenAnswer(
          (_) async => Right([note, linkedNote, backlink]),
        );
        when(() => suggestRelatedNotes(any())).thenAnswer(
          (_) async => const Right([
            RelatedNoteSuggestion(
              id: suggestedIdValue,
              title: 'Concept D',
              score: 0.8,
            ),
          ]),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.load(noteId),
      expect: () => [
        const ZettelDetailLoading(),
        isA<ZettelDetailLoaded>().having(
          (state) => state.suggestions,
          'suggestions',
          isEmpty,
        ),
        isA<ZettelDetailLoaded>().having(
          (state) => state.suggestions,
          'suggestions',
          const [
            RelatedNoteSuggestion(
              id: suggestedIdValue,
              title: 'Concept D',
              score: 0.8,
            ),
          ],
        ),
      ],
      verify: (_) {
        final params =
            verify(() => suggestRelatedNotes(captureAny())).captured.single
                as SuggestRelatedNotesParams;
        expect(params.zettelId, noteId.value);
        expect(params.excludedIds, {
          noteId.value,
          linkedId.value,
          backlinkId.value,
        });
      },
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
      'still loads the note when backlinks fail and the link target '
      'left the vault',
      setUp: () {
        when(() => getZettelById(noteId)).thenAnswer((_) async => Right(note));
        when(() => getBacklinks(noteId)).thenAnswer(
          (_) async => const Left(VaultFailure('Index indisponible')),
        );
        // The linked note is absent from the vault: no title, no edge.
        when(
          () => getAllZettels(any()),
        ).thenAnswer((_) async => Right([note]));
      },
      build: buildCubit,
      act: (cubit) => cubit.load(noteId),
      expect: () => [
        const ZettelDetailLoading(),
        ZettelDetailLoaded(
          zettel: note,
          backlinks: const [],
          linkTitles: const {},
          degrees: const {'20260101120000': 0},
        ),
      ],
    );

    blocTest<ZettelDetailCubit, ZettelDetailState>(
      'degrades to no titles and no degrees when the vault listing fails',
      setUp: () {
        when(() => getZettelById(noteId)).thenAnswer((_) async => Right(note));
        when(
          () => getBacklinks(noteId),
        ).thenAnswer((_) async => Right([backlink]));
        when(() => getAllZettels(any())).thenAnswer(
          (_) async => const Left(VaultFailure('Vault inaccessible')),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.load(noteId),
      expect: () => [
        const ZettelDetailLoading(),
        ZettelDetailLoaded(
          zettel: note,
          backlinks: [backlink],
          linkTitles: const {},
          degrees: const {
            '20260101120000': 0,
            '20260303120000': 0,
          },
        ),
      ],
    );

    group('weave (« Tisser »)', () {
      const suggestion = RelatedNoteSuggestion(
        id: suggestedIdValue,
        title: 'Concept D',
        score: 0.8,
      );
      final suggestedNote = Zettel(
        id: ZettelId.fromString(suggestedIdValue),
        title: 'Concept D',
        body: 'Corps D.',
        createdAt: DateTime(2026, 4, 4, 12),
      );
      final wovenNote = note.copyWith(
        body:
            'Voir [[20260202120000]] pour approfondir.\n\n'
            '[[$suggestedIdValue|Concept D]]\n',
      );

      blocTest<ZettelDetailCubit, ZettelDetailState>(
        'appends the wikilink to the body, saves and reloads',
        setUp: () {
          when(
            () => updateZettel(any()),
          ).thenAnswer((_) async => Right(wovenNote));
          when(
            () => getZettelById(noteId),
          ).thenAnswer((_) async => Right(wovenNote));
          when(
            () => getBacklinks(noteId),
          ).thenAnswer((_) async => const Right(<Zettel>[]));
          when(() => getAllZettels(any())).thenAnswer(
            (_) async => Right([wovenNote, linkedNote, suggestedNote]),
          );
        },
        build: buildCubit,
        seed: () => ZettelDetailLoaded(zettel: note),
        act: (cubit) => cubit.weave(suggestion),
        expect: () => [
          const ZettelDetailLoading(),
          ZettelDetailLoaded(
            zettel: wovenNote,
            backlinks: const [],
            linkTitles: const {
              '20260202120000': 'Concept B',
              suggestedIdValue: 'Concept D',
            },
            degrees: const {
              '20260101120000': 2,
              '20260202120000': 1,
              suggestedIdValue: 1,
            },
          ),
        ],
        verify: (_) {
          verify(() => updateZettel(wovenNote)).called(1);
        },
      );

      blocTest<ZettelDetailCubit, ZettelDetailState>(
        'keeps the loaded state with an error message when saving fails',
        setUp: () {
          when(() => updateZettel(any())).thenAnswer(
            (_) async => const Left(VaultFailure('Sauvegarde impossible')),
          );
        },
        build: buildCubit,
        seed: () => ZettelDetailLoaded(zettel: note),
        act: (cubit) => cubit.weave(suggestion),
        expect: () => [
          ZettelDetailLoaded(
            zettel: note,
            errorMessage: 'Sauvegarde impossible',
          ),
        ],
      );

      blocTest<ZettelDetailCubit, ZettelDetailState>(
        'does nothing when no zettel is loaded',
        build: buildCubit,
        act: (cubit) => cubit.weave(suggestion),
        expect: () => const <ZettelDetailState>[],
        verify: (_) {
          verifyNever(() => updateZettel(any()));
        },
      );
    });

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
