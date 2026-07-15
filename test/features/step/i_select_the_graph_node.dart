import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/graph/presentation/painting/graph_painter.dart';

import 'bdd_world.dart';

/// Usage: I select the graph node {'Concept A'}
///
/// The hit-test lives in graph space: the node's simulated position is read
/// from the [GraphPainter] (which shares simulation and viewport with the
/// gesture layer by reference) and converted to screen coordinates, then the
/// canvas is tapped there. Ticks only advance on pumped frames, so the node
/// cannot move between reading its position and dispatching the tap.
Future<void> iSelectTheGraphNode(WidgetTester tester, String param1) async {
  final zettel = await worldRequireZettelByTitle(param1);
  final canvas = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is GraphPainter,
  );
  expect(canvas, findsOneWidget, reason: 'The graph canvas should be rendered');
  final painter = tester.widget<CustomPaint>(canvas).painter! as GraphPainter;
  final node = painter.simulation.nodes.firstWhere(
    (n) => n.id == zettel.id.value,
    orElse: () => fail("No graph node for the zettel titled '$param1'"),
  );
  final onScreen = painter.viewport.toScreen(Offset(node.x, node.y));

  await tester.tapAt(tester.getTopLeft(canvas) + onScreen);
  // The canvas also listens for double taps, so the single tap is only
  // resolved once the double-tap window (300 ms) has elapsed.
  await tester.pump(const Duration(milliseconds: 400));
  // Compact layout: the persistent Explorer sheet animates up to its
  // summary position while the cubit fetches the « fleur » suggestions.
  // Bounded pumps only — the simulation ticker may still be live, which
  // rules out pumpAndSettle.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
