import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/graph/presentation/painting/graph_painter.dart';

import 'bdd_world.dart';

/// Usage: the node {'Concept A'} is highlighted
///
/// Asserts on the selection state carried by the current [GraphPainter]
/// (selected index + highlight halo), not on rendered pixels.
Future<void> theNodeIsHighlighted(WidgetTester tester, String param1) async {
  final zettel = await worldRequireZettelByTitle(param1);
  final canvas = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is GraphPainter,
  );
  expect(canvas, findsOneWidget, reason: 'The graph canvas should be rendered');
  final painter = tester.widget<CustomPaint>(canvas).painter! as GraphPainter;
  final index = painter.simulation.nodes.indexWhere(
    (n) => n.id == zettel.id.value,
  );
  expect(
    index,
    greaterThanOrEqualTo(0),
    reason: "The graph should contain a node for '$param1'",
  );
  expect(
    painter.selectedIndex,
    index,
    reason: "The node '$param1' should be the selected one",
  );
  expect(
    painter.highlighted,
    contains(index),
    reason: "The node '$param1' should belong to the highlight halo",
  );
}
