import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/graph/domain/usecases/watch_vault.dart';
import 'package:second_brain/features/graph/presentation/bloc/graph_cubit.dart';
import 'package:second_brain/features/graph/presentation/bloc/graph_state.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_all_zettels.dart';

class MockGetAllZettels extends Mock implements GetAllZettels {}

class MockWatchVault extends Mock implements WatchVault {}

const _idA = '20260101100000';
const _idB = '20260102100000';
const _idC = '20260103100000';
const _missingId = '19990101000000';

Zettel _zettel(String id, {String title = 'Titre', String body = ''}) => Zettel(
  id: ZettelId.fromString(id),
  title: title,
  body: body,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  late MockGetAllZettels getAllZettels;
  late MockWatchVault watchVault;

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    getAllZettels = MockGetAllZettels();
    watchVault = MockWatchVault();
    when(
      () => watchVault(any()),
    ).thenAnswer((_) => const Stream<Either<Failure, VaultChanged>>.empty());
  });

  GraphCubit buildCubit() => GraphCubit(getAllZettels, watchVault);

  group('GraphCubit.load', () {
    blocTest<GraphCubit, GraphState>(
      'maps zettels to nodes and wikilinks to edges; '
      'links to unknown ids, self-links and duplicates are ignored',
      build: () {
        when(() => getAllZettels(any())).thenAnswer(
          (_) async => Right([
            _zettel(
              _idA,
              title: 'A',
              // One valid link (to B, twice), one self-link, one link to a
              // note absent from the vault.
              body:
                  'Voir [[$_idB]] et [[$_idA]] et [[$_missingId]] '
                  'et encore [[$_idB|libellé]].',
            ),
            // Reciprocal link B -> A: must not create a second edge.
            _zettel(_idB, title: 'B', body: 'Retour vers [[$_idA]].'),
            _zettel(_idC, title: 'C'),
          ]),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const GraphLoading(),
        const GraphLoaded(
          nodes: [
            GraphNodeInput(id: _idA, title: 'A'),
            GraphNodeInput(id: _idB, title: 'B'),
            GraphNodeInput(id: _idC, title: 'C'),
          ],
          edges: [GraphLinkInput(source: 0, target: 1)],
          revision: 0,
        ),
      ],
    );

    blocTest<GraphCubit, GraphState>(
      'emits GraphLoaded with no edges for an unlinked vault',
      build: () {
        when(
          () => getAllZettels(any()),
        ).thenAnswer((_) async => Right([_zettel(_idA), _zettel(_idB)]));
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const GraphLoading(),
        const GraphLoaded(
          nodes: [
            GraphNodeInput(id: _idA, title: 'Titre'),
            GraphNodeInput(id: _idB, title: 'Titre'),
          ],
          edges: [],
          revision: 0,
        ),
      ],
    );

    blocTest<GraphCubit, GraphState>(
      'emits GraphLoadFailure when the vault cannot be read',
      build: () {
        when(() => getAllZettels(any())).thenAnswer(
          (_) async => const Left(VaultFailure('Vault inaccessible')),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const GraphLoading(),
        const GraphLoadFailure('Vault inaccessible'),
      ],
    );
  });

  group('vault watching', () {
    test(
      'a vault change triggers a rebuild with an incremented revision',
      () async {
        final changes = StreamController<Either<Failure, VaultChanged>>();
        addTearDown(changes.close);
        when(() => watchVault(any())).thenAnswer((_) => changes.stream);
        when(
          () => getAllZettels(any()),
        ).thenAnswer((_) async => Right([_zettel(_idA)]));

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();
        expect((cubit.state as GraphLoaded).revision, 0);

        when(
          () => getAllZettels(any()),
        ).thenAnswer((_) async => Right([_zettel(_idA), _zettel(_idB)]));
        changes.add(const Right(VaultChanged()));
        await pumpEventQueue();

        final state = cubit.state;
        expect(state, isA<GraphLoaded>());
        state as GraphLoaded;
        expect(state.nodes, hasLength(2));
        expect(state.revision, 1);
      },
    );

    test(
      'a failing refresh keeps the last good graph (offline-first)',
      () async {
        final changes = StreamController<Either<Failure, VaultChanged>>();
        addTearDown(changes.close);
        when(() => watchVault(any())).thenAnswer((_) => changes.stream);
        when(
          () => getAllZettels(any()),
        ).thenAnswer((_) async => Right([_zettel(_idA)]));

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();
        final loaded = cubit.state;

        when(
          () => getAllZettels(any()),
        ).thenAnswer((_) async => const Left(VaultFailure('boom')));
        changes.add(const Right(VaultChanged()));
        await pumpEventQueue();

        expect(cubit.state, same(loaded));
      },
    );

    test('close cancels the vault subscription', () async {
      final changes = StreamController<Either<Failure, VaultChanged>>();
      addTearDown(changes.close);
      when(() => watchVault(any())).thenAnswer((_) => changes.stream);
      when(
        () => getAllZettels(any()),
      ).thenAnswer((_) async => Right([_zettel(_idA)]));

      final cubit = buildCubit();
      await cubit.load();
      await cubit.close();

      expect(changes.hasListener, isFalse);
    });
  });
}
