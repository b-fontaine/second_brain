import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/features/graph/presentation/bloc/graph_cubit.dart';
import 'package:second_brain/features/graph/presentation/bloc/graph_state.dart';
import 'package:second_brain/features/graph/presentation/pages/graph_page.dart';
import 'package:second_brain/features/graph/presentation/painting/graph_painter.dart';

class MockGraphCubit extends MockCubit<GraphState> implements GraphCubit {}

void main() {
  const loaded = GraphLoaded(
    nodes: [
      GraphNodeInput(id: '20260101120000', title: 'Concept A'),
      GraphNodeInput(id: '20260202120000', title: 'Concept B'),
    ],
    edges: [GraphLinkInput(source: 0, target: 1)],
    revision: 0,
  );

  late MockGraphCubit cubit;

  setUp(() {
    cubit = MockGraphCubit();
    when(() => cubit.load()).thenAnswer((_) async {});
    getIt.registerFactory<GraphCubit>(() => cubit);
  });

  tearDown(() async {
    await getIt.reset();
  });

  final canvasFinder = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is GraphPainter,
  );

  /// Pumps the page and lets the force simulation settle so node
  /// positions are stable for gesture targeting.
  Future<GraphPainter> pumpLoadedGraph(WidgetTester tester) async {
    whenListen(cubit, const Stream<GraphState>.empty(), initialState: loaded);
    await tester.pumpWidget(const MaterialApp(home: GraphPage()));
    await tester.pumpAndSettle();
    expect(canvasFinder, findsOneWidget);
    return tester.widget<CustomPaint>(canvasFinder).painter! as GraphPainter;
  }

  testWidgets('has no local AppBar and hosts its actions in the overlay', (
    tester,
  ) async {
    await pumpLoadedGraph(tester);

    // The page never carried a local AppBar (its actions live in the
    // overlay). Jalon A: no longer routed as a tab; chantier 2 merges the
    // constellation into the Explorer surface, which keeps that constraint.
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('2 notes · 1 lien'), findsOneWidget);
    expect(find.byTooltip('Recentrer'), findsOneWidget);
    expect(find.byTooltip('Réorganiser'), findsOneWidget);
  });

  testWidgets('exposes a French summary label to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpLoadedGraph(tester);

    expect(
      find.bySemanticsLabel('Graphe de 2 notes et 1 lien'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a two-finger pinch zooms even when centered on a node', (
    tester,
  ) async {
    final painter = await pumpLoadedGraph(tester);
    final node = painter.simulation.nodes[0];
    final canvasTopLeft = tester.getTopLeft(canvasFinder);
    final nodeScreen =
        canvasTopLeft + painter.viewport.toScreen(Offset(node.x, node.y));
    final scaleBefore = painter.viewport.scale;

    // Regression: the pinch focal point lands on a node; the gesture must
    // stay a zoom instead of silently dragging the note around.
    final finger1 = await tester.startGesture(nodeScreen - const Offset(10, 0));
    final finger2 = await tester.startGesture(nodeScreen + const Offset(10, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await finger1.moveBy(const Offset(-40, 0));
    await finger2.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();

    expect(
      painter.viewport.scale,
      greaterThan(scaleBefore),
      reason: 'A pinch over a node should zoom, not drag the node',
    );
  });
}
