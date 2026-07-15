import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/graph/domain/simulation/force_simulation.dart';
import 'package:second_brain/features/graph/presentation/utils/graph_canopy.dart';

void main() {
  group('GraphCanopy.build', () {
    test('groups each node under its most frequent tag', () {
      final canopies = GraphCanopy.build([
        ['flutter'],
        ['flutter'],
        // Belongs to both: 'flutter' (3 occurrences) dominates 'rust' (2).
        ['flutter', 'rust'],
        ['rust'],
      ]);

      expect(canopies, hasLength(2));
      expect(canopies[0].label, 'flutter');
      expect(canopies[0].memberIndices, [0, 1, 2]);
      expect(canopies[1].label, 'rust');
      expect(canopies[1].memberIndices, [3]);
    });

    test('breaks frequency ties alphabetically (deterministic)', () {
      final canopies = GraphCanopy.build([
        // 'a' and 'b' both appear once: the node must land in 'a'.
        ['b', 'a'],
      ]);

      expect(canopies.single.label, 'a');
    });

    test('collects untagged notes under « Sans parcelle »', () {
      final canopies = GraphCanopy.build([
        <String>[],
        ['jardin'],
        <String>[],
      ]);

      final untagged = canopies.singleWhere(
        (c) => c.label == GraphCanopy.untaggedLabel,
      );
      expect(untagged.memberIndices, [0, 2]);
      expect(untagged.count, 2);
    });

    test('sorts canopies by descending count, then by label', () {
      final canopies = GraphCanopy.build([
        ['perso'],
        ['perso'],
        ['projet'],
        <String>[],
      ]);

      expect(canopies.map((c) => c.label).toList(), [
        'perso',
        GraphCanopy.untaggedLabel,
        'projet',
      ]);
      expect(canopies.first.count, 2);
    });

    test('returns no canopy for an empty graph', () {
      expect(GraphCanopy.build(const []), isEmpty);
    });
  });

  group('GraphCanopy.centroidOf', () {
    test('averages the current positions of the members', () {
      final nodes = [
        GraphNode(id: 'a', x: 0, y: 0),
        GraphNode(id: 'b', x: 10, y: 20),
        GraphNode(id: 'c', x: 1000, y: 1000), // not a member: ignored
      ];

      expect(GraphCanopy.centroidOf([0, 1], nodes), const Offset(5, 10));
    });

    test('is origin for an empty member list', () {
      expect(GraphCanopy.centroidOf(const [], const []), Offset.zero);
    });
  });

  group('GraphCanopy.radiusFor', () {
    test('grows with the member count', () {
      expect(
        GraphCanopy.radiusFor(1),
        lessThan(GraphCanopy.radiusFor(10)),
      );
      expect(
        GraphCanopy.radiusFor(10),
        lessThan(GraphCanopy.radiusFor(30)),
      );
    });

    test('is clamped so huge parcels stay readable', () {
      expect(
        GraphCanopy.radiusFor(1000),
        GraphCanopy.radiusFor(2000),
      );
    });
  });

  test('displayLabel shows the tag and the member count', () {
    const canopy = GraphCanopy(
      label: 'philosophie',
      memberIndices: [0, 1, 2],
    );
    expect(canopy.displayLabel, 'philosophie · 3');
  });
}
