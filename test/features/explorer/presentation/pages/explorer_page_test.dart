import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/features/explorer/presentation/bloc/seedling_count_cubit.dart';
import 'package:second_brain/features/explorer/presentation/pages/explorer_page.dart';
import 'package:second_brain/features/graph/presentation/bloc/graph_cubit.dart';
import 'package:second_brain/features/graph/presentation/bloc/graph_state.dart';
import 'package:second_brain/features/graph/presentation/painting/graph_painter.dart';
import 'package:second_brain/features/sync/domain/entities/sync_status.dart';
import 'package:second_brain/features/sync/presentation/bloc/sync_status_cubit.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/presentation/bloc/notes_list/notes_list_bloc.dart';
import 'package:second_brain/features/zettel/presentation/bloc/zettel_detail/zettel_detail_cubit.dart';
import 'package:second_brain/features/zettel/presentation/utils/zettel_maturity.dart';
import 'package:second_brain/features/zettel/presentation/widgets/zettel_list_tile.dart';

class MockGraphCubit extends MockCubit<GraphState> implements GraphCubit {}

class MockNotesListBloc extends MockBloc<NotesListEvent, NotesListState>
    implements NotesListBloc {}

class MockSeedlingCountCubit extends MockCubit<int>
    implements SeedlingCountCubit {}

class MockSyncStatusCubit extends MockCubit<SyncStatusState>
    implements SyncStatusCubit {}

class MockZettelDetailCubit extends MockCubit<ZettelDetailState>
    implements ZettelDetailCubit {}

void main() {
  const idA = '20260101120000';
  const idB = '20260202120000';
  const idC = '20260303120000';

  final zettelA = Zettel(
    id: ZettelId.fromString(idA),
    title: 'Concept A',
    body: 'Voir [[$idB]].',
    createdAt: DateTime(2026, 1, 1, 12),
    tags: const ['philosophie'],
  );
  final zettelB = Zettel(
    id: ZettelId.fromString(idB),
    title: 'Concept B',
    body: 'Corps B, voir [[$idC]].',
    createdAt: DateTime(2026, 2, 2, 12),
  );
  final zettelC = Zettel(
    id: ZettelId.fromString(idC),
    title: 'Concept C',
    body: 'Corps C.',
    createdAt: DateTime(2026, 3, 3, 12),
  );
  final allZettels = [zettelA, zettelB, zettelC];

  const emptyGraph = GraphLoaded(nodes: [], edges: [], revision: 0);
  const loadedGraph = GraphLoaded(
    nodes: [
      GraphNodeInput(id: idA, title: 'Concept A', tags: ['philosophie']),
      GraphNodeInput(id: idB, title: 'Concept B'),
      GraphNodeInput(id: idC, title: 'Concept C'),
    ],
    // A-B and B-C: B is the hub (degree 2 => feuillage).
    edges: [
      GraphLinkInput(source: 0, target: 1),
      GraphLinkInput(source: 1, target: 2),
    ],
    revision: 0,
  );
  final selectedGraph = loadedGraph.copyWith(
    selectedId: idA,
    selectedNeighborIds: const {idB},
    suggestedIds: const {idC},
  );

  late MockGraphCubit graphCubit;
  late MockNotesListBloc notesListBloc;
  late MockSeedlingCountCubit seedlingCubit;
  late MockSyncStatusCubit syncCubit;
  late MockZettelDetailCubit detailCubit;

  setUpAll(() {
    registerFallbackValue(ZettelId.fromString(idA));
  });

  setUp(() {
    graphCubit = MockGraphCubit();
    notesListBloc = MockNotesListBloc();
    seedlingCubit = MockSeedlingCountCubit();
    syncCubit = MockSyncStatusCubit();
    detailCubit = MockZettelDetailCubit();
    when(() => graphCubit.load()).thenAnswer((_) async {});
    when(() => graphCubit.selectNode(any())).thenAnswer((_) async {});
    when(() => seedlingCubit.start()).thenAnswer((_) async {});
    when(() => syncCubit.start()).thenAnswer((_) async {});
    when(() => detailCubit.load(any())).thenAnswer((_) async {});
    getIt
      ..registerFactory<GraphCubit>(() => graphCubit)
      ..registerFactory<NotesListBloc>(() => notesListBloc)
      ..registerFactory<SeedlingCountCubit>(() => seedlingCubit)
      ..registerFactory<SyncStatusCubit>(() => syncCubit)
      ..registerFactory<ZettelDetailCubit>(() => detailCubit);
  });

  tearDown(() async {
    await getIt.reset();
  });

  /// Default happy-path streams; individual tests override with their own
  /// [whenListen] before pumping.
  void stubStates({
    GraphState? graph,
    Stream<GraphState>? graphStream,
    NotesListState? notes,
    Stream<NotesListState>? notesStream,
    int seedlings = 0,
    SyncStatusState sync = const SyncStatusInitial(),
  }) {
    whenListen(
      graphCubit,
      graphStream ?? const Stream<GraphState>.empty(),
      initialState: graph ?? loadedGraph,
    );
    whenListen(
      notesListBloc,
      notesStream ?? const Stream<NotesListState>.empty(),
      initialState: notes ?? NotesListLoaded(zettels: allZettels),
    );
    whenListen(
      seedlingCubit,
      const Stream<int>.empty(),
      initialState: seedlings,
    );
    whenListen(
      syncCubit,
      const Stream<SyncStatusState>.empty(),
      initialState: sync,
    );
  }

  final canvasFinder = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is GraphPainter,
  );

  GraphPainter painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(canvasFinder).painter! as GraphPainter;

  Future<void> pumpExplorer(
    WidgetTester tester, {
    Size size = const Size(500, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ExplorerPage()),
        GoRoute(
          path: '/note/:id',
          builder: (_, state) =>
              Scaffold(body: Text('detail:${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/new',
          builder: (_, _) => const Scaffold(body: Text('page:nouvelle-note')),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('page:réglages')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    // The force simulation cools down and stops its ticker, so settling
    // terminates (same pattern as the former graph_page_test).
    await tester.pumpAndSettle();
  }

  group('état vide', () {
    testWidgets('shows the sprout CTA, keeps the search bar and the FAB', (
      tester,
    ) async {
      stubStates(
        graph: emptyGraph,
        notes: const NotesListLoaded(zettels: []),
      );
      await pumpExplorer(tester);

      expect(find.text("Aucune note pour l'instant…"), findsOneWidget);
      expect(find.textContaining('« Semer »'), findsOneWidget);
      expect(canvasFinder, findsNothing);
      expect(find.byKey(const Key('notes-search-bar')), findsOneWidget);
      expect(find.byKey(const Key('new-note-fab')), findsOneWidget);
      expect(find.byKey(const Key('explorer-sheet')), findsNothing);
    });

    testWidgets('the FAB still opens the note editor', (tester) async {
      stubStates(
        graph: emptyGraph,
        notes: const NotesListLoaded(zettels: []),
      );
      await pumpExplorer(tester);

      await tester.tap(find.byKey(const Key('new-note-fab')));
      await tester.pumpAndSettle();

      expect(find.text('page:nouvelle-note'), findsOneWidget);
    });
  });

  group('état amas', () {
    testWidgets('renders the constellation with the sheet peek', (
      tester,
    ) async {
      stubStates();
      await pumpExplorer(tester);

      expect(canvasFinder, findsOneWidget);
      expect(find.byKey(const Key('explorer-sheet-handle')), findsOneWidget);
      expect(find.text('3 notes'), findsOneWidget);
    });

    testWidgets('keeps the GraphCubit reachable from the canvas element '
        '(contract of the BDD graph steps)', (tester) async {
      stubStates();
      await pumpExplorer(tester);

      expect(
        BlocProvider.of<GraphCubit>(tester.element(canvasFinder)),
        same(graphCubit),
      );
    });

    testWidgets('tapping a node asks the cubit to select it', (tester) async {
      stubStates();
      await pumpExplorer(tester);

      final graphPainter = painter(tester);
      final node = graphPainter.simulation.nodes[0];
      final onScreen =
          tester.getTopLeft(canvasFinder) +
          graphPainter.viewport.toScreen(Offset(node.x, node.y));
      await tester.tapAt(onScreen);
      // The canvas listens for double taps too: the single tap resolves
      // once the double-tap window has elapsed.
      await tester.pump(const Duration(milliseconds: 400));

      verify(() => graphCubit.selectNode(idA)).called(1);
    });

    testWidgets('exposes a French summary label to screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      stubStates();
      await pumpExplorer(tester);

      expect(
        find.bySemanticsLabel('Graphe de 3 notes et 2 liens'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a two-finger pinch zooms even when centered on a node', (
      tester,
    ) async {
      stubStates();
      await pumpExplorer(tester);

      final graphPainter = painter(tester);
      final node = graphPainter.simulation.nodes[0];
      final nodeScreen =
          tester.getTopLeft(canvasFinder) +
          graphPainter.viewport.toScreen(Offset(node.x, node.y));
      final scaleBefore = graphPainter.viewport.scale;

      // Regression inherited from the former GraphPage: the pinch focal
      // point lands on a node; the gesture must stay a zoom instead of
      // silently dragging the note around.
      final finger1 = await tester.startGesture(
        nodeScreen - const Offset(10, 0),
      );
      final finger2 = await tester.startGesture(
        nodeScreen + const Offset(10, 0),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await finger1.moveBy(const Offset(-40, 0));
      await finger2.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 20));
      await finger1.up();
      await finger2.up();
      await tester.pumpAndSettle();

      expect(
        graphPainter.viewport.scale,
        greaterThan(scaleBefore),
        reason: 'A pinch over a node should zoom, not drag the node',
      );
    });
  });

  group('état sélection (compact)', () {
    testWidgets(
      'shows the summary peek (title, counts, plots, Ouvrir) and maps the '
      'selection onto the painter',
      (tester) async {
        stubStates(graphStream: Stream.value(selectedGraph));
        await pumpExplorer(tester);

        // The title and the plot chip may also appear in the sheet's list
        // rows below the summary, hence the non-strict counts.
        expect(find.text('Concept A'), findsWidgets);
        expect(find.text('1 lien · 1 proche'), findsOneWidget);
        expect(find.text('philosophie'), findsWidgets);
        expect(find.byKey(const Key('explorer-open-note')), findsOneWidget);

        final graphPainter = painter(tester);
        expect(graphPainter.selectedIndex, 0);
        expect(graphPainter.highlighted, {0, 1});
        expect(graphPainter.suggestedIndices, {2});
      },
    );

    testWidgets('« Ouvrir » pushes the note detail', (tester) async {
      stubStates(graphStream: Stream.value(selectedGraph));
      await pumpExplorer(tester);

      await tester.tap(find.byKey(const Key('explorer-open-note')));
      await tester.pumpAndSettle();

      expect(find.text('detail:$idA'), findsOneWidget);
    });
  });

  group('état recherche', () {
    testWidgets('typing forwards the query to the notes list bloc', (
      tester,
    ) async {
      stubStates();
      await pumpExplorer(tester);

      await tester.enterText(
        find.byKey(const Key('notes-search-bar')),
        'Concept',
      );
      await tester.pump();

      verify(
        () => notesListBloc.add(const NotesListQueryChanged('Concept')),
      ).called(1);
    });

    testWidgets(
      'search results float under the bar and light the matched nodes',
      (tester) async {
        stubStates(
          notesStream: Stream.value(
            NotesListLoaded(zettels: [zettelA], query: 'Concept A'),
          ),
        );
        await pumpExplorer(tester);

        verify(() => graphCubit.setHighlighted({idA})).called(1);
        final results = find.byKey(const Key('explorer-search-results'));
        expect(results, findsOneWidget);
        final resultTile = find.descendant(
          of: results,
          matching: find.byType(ZettelListTile),
        );
        expect(resultTile, findsOneWidget);

        await tester.tap(resultTile);
        await tester.pumpAndSettle();
        expect(find.text('detail:$idA'), findsOneWidget);
      },
    );

    testWidgets('an empty result set shows the French empty message', (
      tester,
    ) async {
      stubStates(
        notesStream: Stream.value(
          const NotesListLoaded(zettels: [], query: 'zzz'),
        ),
      );
      await pumpExplorer(tester);

      expect(
        find.text('Aucune note ne correspond à votre recherche.'),
        findsOneWidget,
      );
    });

    testWidgets('clearing the query resets the highlight', (tester) async {
      stubStates(
        notesStream: Stream.value(NotesListLoaded(zettels: allZettels)),
      );
      await pumpExplorer(tester);

      verify(() => graphCubit.setHighlighted(const <String>{})).called(1);
      expect(find.byKey(const Key('explorer-search-results')), findsNothing);
    });
  });

  group('état liste', () {
    testWidgets(
      'raising the sheet reveals the chronological groups with maturity dots',
      (tester) async {
        stubStates();
        await pumpExplorer(tester);

        await tester.drag(
          find.byKey(const Key('explorer-sheet-handle')),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();

        expect(find.text('mars 2026'), findsOneWidget);
        expect(find.text('février 2026'), findsOneWidget);
        expect(find.text('janvier 2026'), findsOneWidget);
        expect(find.byType(ZettelListTile), findsNWidgets(3));
        // B carries two links (A-B, B-C): feuillage; A and C one: pousse.
        final tileB = tester.widget<ZettelListTile>(
          find.widgetWithText(ZettelListTile, 'Concept B'),
        );
        expect(tileB.maturity, ZettelMaturity.feuillage);
        final tileA = tester.widget<ZettelListTile>(
          find.widgetWithText(ZettelListTile, 'Concept A'),
        );
        expect(tileA.maturity, ZettelMaturity.pousse);
      },
    );

    testWidgets('tapping a row opens the note detail', (tester) async {
      stubStates();
      await pumpExplorer(tester);

      await tester.drag(
        find.byKey(const Key('explorer-sheet-handle')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ZettelListTile, 'Concept B'));
      await tester.pumpAndSettle();

      expect(find.text('detail:$idB'), findsOneWidget);
    });
  });

  group('pills', () {
    testWidgets('shows « n semis » when captures are pending', (tester) async {
      stubStates(seedlings: 2);
      await pumpExplorer(tester);

      expect(find.text('2 semis'), findsOneWidget);
    });

    testWidgets('hides the seedling pill when the inbox is empty', (
      tester,
    ) async {
      stubStates();
      await pumpExplorer(tester);

      expect(find.byKey(const Key('explorer-seedling-pill')), findsNothing);
    });

    testWidgets('shows « À jour » when synced and online', (tester) async {
      stubStates(
        sync: const SyncStatusReady(
          status: SyncStatus(state: SyncState.upToDate),
          isOnline: true,
        ),
      );
      await pumpExplorer(tester);

      expect(find.text('À jour'), findsOneWidget);
    });

    testWidgets('shows « Hors ligne » when the network is gone', (
      tester,
    ) async {
      stubStates(
        sync: const SyncStatusReady(
          status: SyncStatus(state: SyncState.upToDate),
          isOnline: false,
        ),
      );
      await pumpExplorer(tester);

      expect(find.text('Hors ligne'), findsOneWidget);
    });
  });

  group('desktop (expanded)', () {
    const desktop = Size(1200, 900);

    testWidgets(
      'a selection opens the right reading panel instead of the sheet',
      (tester) async {
        whenListen(
          detailCubit,
          const Stream<ZettelDetailState>.empty(),
          initialState: ZettelDetailLoaded(zettel: zettelA),
        );
        stubStates(graph: selectedGraph);
        await pumpExplorer(tester, size: desktop);

        expect(find.byKey(const Key('zettel-reading-panel')), findsOneWidget);
        expect(find.byKey(const Key('explorer-sheet')), findsNothing);

        await tester.tap(find.byTooltip('Fermer'));
        verify(() => graphCubit.selectNode(null)).called(1);
      },
    );

    testWidgets('has no settings gear (it lives in the rail)', (tester) async {
      stubStates();
      await pumpExplorer(tester, size: desktop);

      expect(find.byIcon(Icons.settings_outlined), findsNothing);
    });

    testWidgets('the pills row toggles the left notes panel', (tester) async {
      stubStates();
      await pumpExplorer(tester, size: desktop);
      expect(find.byKey(const Key('explorer-notes-panel')), findsNothing);

      await tester.tap(find.byTooltip('Liste des notes'));
      await tester.pumpAndSettle();

      final panel = find.byKey(const Key('explorer-notes-panel'));
      expect(panel, findsOneWidget);
      expect(
        find.descendant(of: panel, matching: find.byType(ZettelListTile)),
        findsNWidgets(3),
      );

      await tester.tap(find.byTooltip('Liste des notes'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('explorer-notes-panel')), findsNothing);
    });
  });

  group('échec de chargement', () {
    testWidgets('shows the error and retries on demand', (tester) async {
      stubStates(graph: const GraphLoadFailure('coffre illisible'));
      await pumpExplorer(tester);

      expect(find.text('coffre illisible'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      // Once at page creation, once from the retry button.
      verify(() => graphCubit.load()).called(2);
    });
  });
}
