import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/graph/presentation/utils/graph_lod.dart';

void main() {
  group('GraphLod.forScale', () {
    test('thresholds are ordered and inside the viewport zoom range', () {
      expect(GraphLod.canopyMaxScale, lessThan(GraphLod.fullLabelsMinScale));
      expect(GraphLod.canopyMaxScale, greaterThan(0.05));
      expect(GraphLod.fullLabelsMinScale, lessThan(4.0));
    });

    test('far out (< s1) collapses into canopies', () {
      expect(GraphLod.forScale(0.05), GraphLod.canopy);
      expect(GraphLod.forScale(GraphLod.canopyMaxScale - 0.001), GraphLod.canopy);
    });

    test('mid-range (s1..s2) shows nodes with hub labels only', () {
      expect(GraphLod.forScale(GraphLod.canopyMaxScale), GraphLod.hubs);
      expect(GraphLod.forScale(0.5), GraphLod.hubs);
      expect(GraphLod.forScale(GraphLod.fullLabelsMinScale), GraphLod.hubs);
    });

    test('zoomed in (> s2) shows every label', () {
      expect(
        GraphLod.forScale(GraphLod.fullLabelsMinScale + 0.001),
        GraphLod.detail,
      );
      expect(GraphLod.forScale(1.0), GraphLod.detail);
      expect(GraphLod.forScale(4.0), GraphLod.detail);
    });
  });
}
