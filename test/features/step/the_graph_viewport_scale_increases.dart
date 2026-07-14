import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/graph/presentation/painting/graph_painter.dart';

import 'i_zoom_into_the_graph.dart' show graphViewportScaleBeforeZoom;

/// Usage: the graph viewport scale increases
///
/// The [GraphViewport] is shared by reference between the gesture layer and
/// the painter, so the painter exposes the live scale to assert on.
Future<void> theGraphViewportScaleIncreases(WidgetTester tester) async {
  final canvas = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is GraphPainter,
  );
  expect(canvas, findsOneWidget, reason: 'The graph canvas should be rendered');
  final painter = tester.widget<CustomPaint>(canvas).painter! as GraphPainter;
  expect(
    painter.viewport.scale,
    greaterThan(graphViewportScaleBeforeZoom),
    reason:
        'Zooming in should increase the viewport scale '
        '(before: $graphViewportScaleBeforeZoom)',
  );
}
