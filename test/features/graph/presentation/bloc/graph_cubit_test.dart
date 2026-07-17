import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/graph/domain/entities/related_note_suggestion.dart';
import 'package:second_brain/features/graph/domain/usecases/suggest_related_notes.dart';
import 'package:second_brain/features/graph/domain/usecases/watch_vault.dart';
import 'package:second_brain/features/graph/presentation/bloc/graph_cubit.dart';
import 'package:second_brain/features/graph/presentation/bloc/graph_state.dart';
import 'package:second_brain/features/graph/presentation/utils/graph_canopy.dart';
import 'package:second_brain/features/graph/presentation/utils/graph_lod.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_all_zettels.dart';

class MockGetAllZettels extends Mock implements GetAllZettels {}

class MockWatchVault extends Mock implements WatchVault {}

class MockSuggestRelatedNotes extends Mock implements SuggestRelatedNotes {}

const _idA = '20260101100000';
const _idB = '20260102100000';
const _idC = '20260103100000';
const _missingId = '19990101000000';

Zettel _zettel(
  String id, {
  String title = 'Titre',
  String body = '',
  List<String> tags = const [],
}) => Zettel(
  id: ZettelId.fromString(id),
  title: title,
  body: body,
  createdAt: DateTime(2026, 1, 1),
  tags: tags,
);

void main() {
  late MockGetAllZettels getAllZettels;
  late MockWatchVault watchVault;
  late MockSuggestRelatedNotes suggestRelatedNotes;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const SuggestRelatedNotesParams(zettelId: ''));
  });

  setUp(() {
    getAllZettels = MockGetAllZettels();
    watchVault = MockWatchVault();
    suggestRelatedNotes = MockSuggestRelatedNotes();
    when(
      () => watchVault(any()),
    ).thenAnswer((_) => const Stream<Either<Failure, VaultChanged>>.empty());
    when(
      () => suggestRelatedNotes(any()),
    ).thenAnswer((_) async => const Right(<RelatedNoteSuggestion>[]));
  });

  GraphCubit buildCubit() =>
      GraphCubit(getAllZettels, watchVault, suggestRelatedNotes);

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
          canopies: [
            GraphCanopy(
              label: GraphCanopy.untaggedLabel,
              memberIndices: [0, 1, 2],
            ),
          ],
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
          canopies: [
            GraphCanopy(
              label: GraphCanopy.untaggedLabel,
              memberIndices: [0, 1],
            ),
          ],
        ),
      ],
    );

    blocTest<GraphCubit, GraphState>(
      'propagates tags to the nodes and groups canopies by dominant tag',
      build: () {
        when(() => getAllZettels(any())).thenAnswer(
          (_) async => Right([
            _zettel(_idA, title: 'A', tags: ['jardin']),
            _zettel(_idB, title: 'B', tags: ['jardin', 'code']),
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
            GraphNodeInput(id: _idA, title: 'A', tags: ['jardin']),
            GraphNodeInput(id: _idB, title: 'B', tags: ['jardin', 'code']),
            GraphNodeInput(id: _idC, title: 'C'),
          ],
          edges: [],
          revision: 0,
          canopies: [
            // 'jardin' (2 occurrences) dominates 'code' (1) for node B.
            GraphCanopy(label: 'jardin', memberIndices: [0, 1]),
            GraphCanopy(
              label: GraphCanopy.untaggedLabel,
              memberIndices: [2],
            ),
          ],
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

  group('selectNode', () {
    setUp(() {
      when(() => getAllZettels(any())).thenAnswer(
        (_) async => Right([
          _zettel(_idA, title: 'A', body: 'Voir [[$_idB]].'),
          _zettel(_idB, title: 'B'),
          _zettel(_idC, title: 'C'),
        ]),
      );
    });

    test('exposes the selection, its neighbors and the fleur suggestions '
        'from the local index (already-linked ids excluded)', () async {
      when(() => suggestRelatedNotes(any())).thenAnswer(
        (_) async =>
            const Right([RelatedNoteSuggestion(id: _idC, title: 'C')]),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.selectNode(_idA);

      final state = cubit.state as GraphLoaded;
      expect(state.selectedId, _idA);
      expect(state.selectedNeighborIds, {_idB});
      expect(state.suggestedIds, {_idC});
      final params =
          verify(() => suggestRelatedNotes(captureAny())).captured.single
              as SuggestRelatedNotesParams;
      expect(params.zettelId, _idA);
      // The note itself and its linked neighbors are never suggested.
      expect(params.excludedIds, {_idA, _idB});
    });

    test('selectNode(null) clears the selection and the suggestions', () async {
      when(() => suggestRelatedNotes(any())).thenAnswer(
        (_) async =>
            const Right([RelatedNoteSuggestion(id: _idC, title: 'C')]),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.selectNode(_idA);

      await cubit.selectNode(null);

      final state = cubit.state as GraphLoaded;
      expect(state.selectedId, isNull);
      expect(state.selectedNeighborIds, isEmpty);
      expect(state.suggestedIds, isEmpty);
    });

    test('drops stale suggestions when the selection moved on', () async {
      final completer =
          Completer<Either<Failure, List<RelatedNoteSuggestion>>>();
      when(
        () => suggestRelatedNotes(any()),
      ).thenAnswer((_) => completer.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();

      final pending = cubit.selectNode(_idA);
      await cubit.selectNode(null);
      completer.complete(
        const Right([RelatedNoteSuggestion(id: _idC, title: 'C')]),
      );
      await pending;

      final state = cubit.state as GraphLoaded;
      expect(state.selectedId, isNull);
      expect(state.suggestedIds, isEmpty);
    });

    test('ignores suggested ids absent from the graph', () async {
      when(() => suggestRelatedNotes(any())).thenAnswer(
        (_) async => const Right([
          RelatedNoteSuggestion(id: _missingId, title: 'Fantôme'),
        ]),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.selectNode(_idA);

      expect((cubit.state as GraphLoaded).suggestedIds, isEmpty);
    });

    test('keeps the selection without fleurs when the index fails', () async {
      when(() => suggestRelatedNotes(any())).thenAnswer(
        (_) async => const Left(VaultFailure('index indisponible')),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.selectNode(_idA);

      final state = cubit.state as GraphLoaded;
      expect(state.selectedId, _idA);
      expect(state.suggestedIds, isEmpty);
    });

    test('is a no-op before the graph is loaded', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.selectNode(_idA);

      expect(cubit.state, const GraphInitial());
      verifyNever(() => suggestRelatedNotes(any()));
    });
  });

  group('setHighlighted (search mode)', () {
    setUp(() {
      when(
        () => getAllZettels(any()),
      ).thenAnswer((_) async => Right([_zettel(_idA), _zettel(_idB)]));
    });

    test('lights the given ids and an empty set restores normal mode',
        () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();

      cubit.setHighlighted(const {_idA});
      expect((cubit.state as GraphLoaded).highlightedIds, {_idA});

      cubit.setHighlighted(const {});
      expect((cubit.state as GraphLoaded).highlightedIds, isEmpty);
    });

    test('is a no-op before the graph is loaded', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.setHighlighted(const {_idA});

      expect(cubit.state, const GraphInitial());
    });
  });

  group('viewScaleChanged', () {
    test('emits only when the LOD band changes', () async {
      when(
        () => getAllZettels(any()),
      ).thenAnswer((_) async => Right([_zettel(_idA)]));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();
      expect((cubit.state as GraphLoaded).lod, GraphLod.detail);

      final emitted = <GraphLod>[];
      final subscription = cubit.stream.listen(
        (state) => emitted.add((state as GraphLoaded).lod),
      );
      addTearDown(subscription.cancel);

      cubit.viewScaleChanged(0.2); // detail -> canopy
      cubit.viewScaleChanged(0.1); // still canopy: no emission
      cubit.viewScaleChanged(0.5); // canopy -> hubs
      cubit.viewScaleChanged(2.0); // hubs -> detail
      await pumpEventQueue();

      expect(emitted, [GraphLod.canopy, GraphLod.hubs, GraphLod.detail]);
    });

    test('is a no-op before the graph is loaded', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.viewScaleChanged(0.1);

      expect(cubit.state, const GraphInitial());
    });
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
      'a refresh carries the interaction state over and drops vanished ids',
      () async {
        final changes = StreamController<Either<Failure, VaultChanged>>();
        addTearDown(changes.close);
        when(() => watchVault(any())).thenAnswer((_) => changes.stream);
        when(() => getAllZettels(any())).thenAnswer(
          (_) async => Right([
            _zettel(_idA, title: 'A', body: 'Voir [[$_idB]].'),
            _zettel(_idB, title: 'B'),
            _zettel(_idC, title: 'C'),
          ]),
        );
        when(() => suggestRelatedNotes(any())).thenAnswer(
          (_) async =>
              const Right([RelatedNoteSuggestion(id: _idC, title: 'C')]),
        );

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.selectNode(_idA);
        cubit.setHighlighted(const {_idA, _idC});

        // B and C leave the vault: the selection survives, its neighborhood
        // and the ids pointing at removed notes do not.
        when(
          () => getAllZettels(any()),
        ).thenAnswer((_) async => Right([_zettel(_idA, title: 'A')]));
        changes.add(const Right(VaultChanged()));
        await pumpEventQueue();

        final state = cubit.state as GraphLoaded;
        expect(state.revision, 1);
        expect(state.selectedId, _idA);
        expect(state.selectedNeighborIds, isEmpty);
        expect(state.highlightedIds, {_idA});
        expect(state.suggestedIds, isEmpty);
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
