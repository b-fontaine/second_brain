import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/graph/presentation/painting/graph_painter.dart';

/// Viewport scale recorded right before the zoom gesture, so the Then step
/// "the graph viewport scale increases" can compare against it.
double graphViewportScaleBeforeZoom = 1.0;

/// Usage: I zoom into the graph
///
/// Zooms with a mouse-wheel scroll-up at the canvas center (the page's
/// `Listener.onPointerSignal` handles [PointerScrollEvent]s as zooms).
Future<void> iZoomIntoTheGraph(WidgetTester tester) async {
  final canvas = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is GraphPainter,
  );
  expect(canvas, findsOneWidget, reason: 'The graph canvas should be rendered');
  final painter = tester.widget<CustomPaint>(canvas).painter! as GraphPainter;
  graphViewportScaleBeforeZoom = painter.viewport.scale;

  final center = tester.getCenter(canvas);
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(center));
  // Scrolling up (negative dy) zooms in.
  await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
  await tester.pump();
}
