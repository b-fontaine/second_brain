import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/graph/presentation/painting/graph_painter.dart';

/// Usage: the constellation lights {1} node
///
/// Search mode: the matched nodes stay lit while the rest of the
/// constellation dims. Asserts on the lit indices carried by the current
/// [GraphPainter], not on rendered pixels.
Future<void> theConstellationLightsNode(WidgetTester tester, num param1) async {
  final canvas = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is GraphPainter,
  );
  expect(canvas, findsOneWidget, reason: 'The graph canvas should be rendered');
  final painter = tester.widget<CustomPaint>(canvas).painter! as GraphPainter;
  expect(
    painter.litIndices,
    hasLength(param1.toInt()),
    reason: 'The search should keep exactly $param1 node(s) lit',
  );
}
