import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/usecases/create_zettel.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_zettel_by_id.dart';
import 'package:second_brain/features/zettel/domain/usecases/transplant_seedling.dart';
import 'package:second_brain/features/zettel/domain/usecases/update_zettel.dart';
import 'package:second_brain/features/zettel/presentation/bloc/zettel_edit/zettel_edit_bloc.dart';

class MockCreateZettel extends Mock implements CreateZettel {}

class MockUpdateZettel extends Mock implements UpdateZettel {}

class MockGetZettelById extends Mock implements GetZettelById {}

class MockTransplantSeedling extends Mock implements TransplantSeedling {}

void main() {
  final noteId = ZettelId.fromString('20260101120000');
  final existing = Zettel(
    id: noteId,
    title: 'Concept A',
    body: 'Corps initial.',
    createdAt: DateTime(2026, 1, 1, 12),
    tags: const ['cognition'],
  );
  final created = Zettel(
    id: ZettelId.fromString('20260714103000'),
    title: 'Nouvelle idée',
    body: 'Corps.',
    createdAt: DateTime(2026, 7, 14, 10, 30),
    tags: const ['memoire'],
  );

  final draftItem = InboxItem(
    id: '20260716094100',
    type: CaptureType.dictation,
    rawText: 'Texte dicté du brouillon.',
    capturedAt: DateTime(2026, 7, 16, 9, 41),
    title: 'Brouillon dicté',
    tags: const ['jardin'],
  );

  late MockCreateZettel createZettel;
  late MockUpdateZettel updateZettel;
  late MockGetZettelById getZettelById;
  late MockTransplantSeedling transplantSeedling;

  setUpAll(() {
    registerFallbackValue(ZettelId.fromString('20260101120000'));
    registerFallbackValue(
      const CreateZettelParams(title: 'fallback', body: ''),
    );
    registerFallbackValue(
      Zettel(
        id: ZettelId.fromString('20260101120000'),
        title: 'fallback',
        body: '',
        createdAt: DateTime(2026),
      ),
    );
    registerFallbackValue(TransplantSeedlingParams(item: draftItem));
  });

  setUp(() {
    createZettel = MockCreateZettel();
    updateZettel = MockUpdateZettel();
    getZettelById = MockGetZettelById();
    transplantSeedling = MockTransplantSeedling();
  });

  ZettelEditBloc buildBloc() => ZettelEditBloc(
    createZettel,
    updateZettel,
    getZettelById,
    transplantSeedling,
  );

  group('ZettelEditBloc', () {
    test('initial state is ZettelEditInitial', () {
      expect(buildBloc().state, const ZettelEditInitial());
    });

    blocTest<ZettelEditBloc, ZettelEditState>(
      'emits [ready] immediately in creation mode',
      build: buildBloc,
      act: (bloc) => bloc.add(const ZettelEditStarted()),
      expect: () => [const ZettelEditReady()],
    );

    blocTest<ZettelEditBloc, ZettelEditState>(
      'emits [loading, ready(initial)] in edition mode',
      setUp: () {
        when(
          () => getZettelById(noteId),
        ).thenAnswer((_) async => Right(existing));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(ZettelEditStarted(id: noteId)),
      expect: () => [
        const ZettelEditLoading(),
        ZettelEditReady(initial: existing),
      ],
    );

    blocTest<ZettelEditBloc, ZettelEditState>(
      'emits a blocking error when the note to edit cannot be loaded',
      setUp: () {
        when(
          () => getZettelById(noteId),
        ).thenAnswer((_) async => Left(ZettelNotFoundFailure(noteId.value)));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(ZettelEditStarted(id: noteId)),
      expect: () => [
        const ZettelEditLoading(),
        ZettelEditError('Note introuvable : ${noteId.value}', blocking: true),
      ],
    );

    blocTest<ZettelEditBloc, ZettelEditState>(
      'rejects an empty title without calling any use case',
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const ZettelEditSubmitted(title: '   ', body: 'Corps.')),
      expect: () => [const ZettelEditError(ZettelEditBloc.emptyTitleMessage)],
      verify: (_) {
        verifyNever(() => createZettel(any()));
        verifyNever(() => updateZettel(any()));
      },
    );

    blocTest<ZettelEditBloc, ZettelEditState>(
      'emits [saving, saved] and calls CreateZettel in creation mode',
      setUp: () {
        when(() => createZettel(any())).thenAnswer((_) async => Right(created));
      },
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const ZettelEditStarted())
        ..add(
          const ZettelEditSubmitted(
            title: '  Nouvelle idée  ',
            body: 'Corps.',
            tags: ['memoire'],
          ),
        ),
      expect: () => [
        const ZettelEditReady(),
        const ZettelEditSaving(),
        ZettelEditSaved(created),
      ],
      verify: (_) {
        verify(
          () => createZettel(
            const CreateZettelParams(
              title: 'Nouvelle idée',
              body: 'Corps.',
              tags: ['memoire'],
            ),
          ),
        ).called(1);
        verifyNever(() => updateZettel(any()));
      },
    );

    blocTest<ZettelEditBloc, ZettelEditState>(
      'emits [saving, saved] and calls UpdateZettel in edition mode',
      setUp: () {
        when(
          () => getZettelById(noteId),
        ).thenAnswer((_) async => Right(existing));
        when(() => updateZettel(any())).thenAnswer(
          (invocation) async =>
              Right(invocation.positionalArguments.first as Zettel),
        );
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(ZettelEditStarted(id: noteId));
        // Wait for the note to load before submitting, as the UI does.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const ZettelEditSubmitted(
            title: 'Concept A révisé',
            body: 'Corps mis à jour.',
            tags: ['cognition', 'memoire'],
          ),
        );
      },
      expect: () => [
        const ZettelEditLoading(),
        ZettelEditReady(initial: existing),
        const ZettelEditSaving(),
        ZettelEditSaved(
          existing.copyWith(
            title: 'Concept A révisé',
            body: 'Corps mis à jour.',
            tags: ['cognition', 'memoire'],
          ),
        ),
      ],
      verify: (_) {
        verify(
          () => updateZettel(
            existing.copyWith(
              title: 'Concept A révisé',
              body: 'Corps mis à jour.',
              tags: ['cognition', 'memoire'],
            ),
          ),
        ).called(1);
        verifyNever(() => createZettel(any()));
      },
    );

    blocTest<ZettelEditBloc, ZettelEditState>(
      'emits [ready(draft)] immediately in nursery transplant mode',
      build: buildBloc,
      act: (bloc) => bloc.add(ZettelEditStarted(draftItem: draftItem)),
      expect: () => [ZettelEditReady(draft: draftItem)],
      verify: (_) => verifyNever(() => getZettelById(any())),
    );

    blocTest<ZettelEditBloc, ZettelEditState>(
      'transplants the draft with the edited values instead of creating '
      'a bare note',
      setUp: () {
        when(
          () => transplantSeedling(any()),
        ).thenAnswer((_) async => Right(created));
      },
      build: buildBloc,
      act: (bloc) => bloc
        ..add(ZettelEditStarted(draftItem: draftItem))
        ..add(
          const ZettelEditSubmitted(
            title: 'Titre repiqué',
            body: 'Corps édité.',
            tags: ['jardin', 'semis'],
          ),
        ),
      expect: () => [
        ZettelEditReady(draft: draftItem),
        const ZettelEditSaving(),
        ZettelEditSaved(created),
      ],
      verify: (_) {
        verify(
          () => transplantSeedling(
            TransplantSeedlingParams(
              item: draftItem,
              title: 'Titre repiqué',
              body: 'Corps édité.',
              tags: const ['jardin', 'semis'],
            ),
          ),
        ).called(1);
        verifyNever(() => createZettel(any()));
        verifyNever(() => updateZettel(any()));
      },
    );

    blocTest<ZettelEditBloc, ZettelEditState>(
      'surfaces a transplant failure as a non-blocking error',
      setUp: () {
        when(() => transplantSeedling(any())).thenAnswer(
          (_) async => const Left(VaultFailure('Écriture impossible')),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc
        ..add(ZettelEditStarted(draftItem: draftItem))
        ..add(const ZettelEditSubmitted(title: 'Titre', body: 'Corps.')),
      expect: () => [
        ZettelEditReady(draft: draftItem),
        const ZettelEditSaving(),
        const ZettelEditError('Écriture impossible'),
      ],
    );

    blocTest<ZettelEditBloc, ZettelEditState>(
      'emits [saving, error] when the save fails',
      setUp: () {
        when(() => createZettel(any())).thenAnswer(
          (_) async => const Left(VaultFailure('Écriture impossible')),
        );
      },
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const ZettelEditSubmitted(title: 'Titre', body: 'Corps.')),
      expect: () => [
        const ZettelEditSaving(),
        const ZettelEditError('Écriture impossible'),
      ],
    );
  });
}
