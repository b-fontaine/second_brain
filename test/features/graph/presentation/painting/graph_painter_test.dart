import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/graph/presentation/painting/graph_painter.dart';

void main() {
  group('GraphPainter.edgeMayBeVisible', () {
    const visible = Rect.fromLTRB(-200, -200, 200, 200);

    test('keeps an edge crossing the viewport with both endpoints outside', () {
      // Regression: endpoint-containment culling dropped this edge even
      // though it crosses the whole viewport.
      expect(
        GraphPainter.edgeMayBeVisible(
          visible,
          const Offset(-1000, 0),
          const Offset(1000, 0),
        ),
        isTrue,
      );
    });

    test('keeps a diagonal edge spanning the viewport', () {
      expect(
        GraphPainter.edgeMayBeVisible(
          visible,
          const Offset(-500, -500),
          const Offset(500, 500),
        ),
        isTrue,
      );
    });

    test('keeps an edge with one endpoint inside', () {
      expect(
        GraphPainter.edgeMayBeVisible(
          visible,
          const Offset(0, 0),
          const Offset(5000, 5000),
        ),
        isTrue,
      );
    });

    test('culls an edge fully off to one side', () {
      expect(
        GraphPainter.edgeMayBeVisible(
          visible,
          const Offset(300, -100),
          const Offset(1000, 100),
        ),
        isFalse,
      );
    });

    test('culls an edge fully above the viewport', () {
      expect(
        GraphPainter.edgeMayBeVisible(
          visible,
          const Offset(-1000, -300),
          const Offset(1000, -250),
        ),
        isFalse,
      );
    });
  });

  group('GraphViewport', () {
    test('toGraph and toScreen are inverse transforms', () {
      final viewport = GraphViewport()
        ..scale = 2
        ..pan = const Offset(10, -5);
      const screen = Offset(42, 17);

      expect(viewport.toScreen(viewport.toGraph(screen)), screen);
    });
  });
}
