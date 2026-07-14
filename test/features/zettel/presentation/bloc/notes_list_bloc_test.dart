import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_all_zettels.dart';
import 'package:second_brain/features/zettel/domain/usecases/search_zettels.dart';
import 'package:second_brain/features/zettel/presentation/bloc/notes_list/notes_list_bloc.dart';

class MockGetAllZettels extends Mock implements GetAllZettels {}

class MockSearchZettels extends Mock implements SearchZettels {}

class MockZettelRepository extends Mock implements ZettelRepository {}

void main() {
  final noteA = Zettel(
    id: ZettelId.fromString('20260101120000'),
    title: 'Concept A',
    body: 'Corps de la note A.',
    createdAt: DateTime(2026, 1, 1, 12),
  );
  final noteB = Zettel(
    id: ZettelId.fromString('20260202120000'),
    title: 'Concept B',
    body: 'Corps de la note B.',
    createdAt: DateTime(2026, 2, 2, 12),
  );

  late MockGetAllZettels getAllZettels;
  late MockSearchZettels searchZettels;
  late MockZettelRepository repository;
  late StreamController<VaultChanged> vaultController;

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    getAllZettels = MockGetAllZettels();
    searchZettels = MockSearchZettels();
    repository = MockZettelRepository();
    vaultController = StreamController<VaultChanged>.broadcast();
    when(
      () => repository.watchVault(),
    ).thenAnswer((_) => vaultController.stream);
  });

  tearDown(() async {
    await vaultController.close();
  });

  NotesListBloc buildBloc() =>
      NotesListBloc(getAllZettels, searchZettels, repository);

  group('NotesListBloc', () {
    test('initial state is NotesListInitial', () {
      expect(buildBloc().state, const NotesListInitial());
    });

    blocTest<NotesListBloc, NotesListState>(
      'emits [loading, loaded] when started and GetAllZettels succeeds',
      setUp: () {
        when(
          () => getAllZettels(any()),
        ).thenAnswer((_) async => Right([noteA]));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const NotesListStarted()),
      expect: () => [
        const NotesListLoading(),
        NotesListLoaded(zettels: [noteA], query: ''),
      ],
      verify: (_) {
        verify(() => repository.watchVault()).called(1);
      },
    );

    blocTest<NotesListBloc, NotesListState>(
      'emits [loading, error] when GetAllZettels fails',
      setUp: () {
        when(
          () => getAllZettels(any()),
        ).thenAnswer((_) async => const Left(VaultFailure('Vault illisible')));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const NotesListStarted()),
      expect: () => [
        const NotesListLoading(),
        const NotesListError('Vault illisible'),
      ],
    );

    blocTest<NotesListBloc, NotesListState>(
      'debounces successive queries and only searches the last one',
      setUp: () {
        when(() => searchZettels('ab')).thenAnswer((_) async => Right([noteB]));
      },
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const NotesListQueryChanged('a'))
        ..add(const NotesListQueryChanged('ab')),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        NotesListLoaded(zettels: [noteB], query: 'ab'),
      ],
      verify: (_) {
        verify(() => searchZettels('ab')).called(1);
        verifyNever(() => searchZettels('a'));
      },
    );

    blocTest<NotesListBloc, NotesListState>(
      'emits error when the search fails',
      setUp: () {
        when(() => searchZettels('boom')).thenAnswer(
          (_) async => const Left(VaultFailure('Recherche impossible')),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const NotesListQueryChanged('boom')),
      wait: const Duration(milliseconds: 400),
      expect: () => [const NotesListError('Recherche impossible')],
    );

    blocTest<NotesListBloc, NotesListState>(
      'reloads with the current query when the vault changes',
      setUp: () {
        when(
          () => getAllZettels(any()),
        ).thenAnswer((_) async => Right([noteA]));
        when(
          () => searchZettels(''),
        ).thenAnswer((_) async => Right([noteA, noteB]));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const NotesListStarted());
        // Let the started handler subscribe to the vault stream.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        vaultController.add(const VaultChanged());
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        const NotesListLoading(),
        NotesListLoaded(zettels: [noteA], query: ''),
        NotesListLoaded(zettels: [noteA, noteB], query: ''),
      ],
    );

    blocTest<NotesListBloc, NotesListState>(
      'stops listening to the vault after close',
      setUp: () {
        when(
          () => getAllZettels(any()),
        ).thenAnswer((_) async => Right([noteA]));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const NotesListStarted());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await bloc.close();
        vaultController.add(const VaultChanged());
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        const NotesListLoading(),
        NotesListLoaded(zettels: [noteA], query: ''),
      ],
    );
  });
}
