import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/graph/domain/simulation/force_simulation.dart';

double _distance(GraphNode a, GraphNode b) {
  final dx = a.x - b.x, dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

List<GraphNode> _nodes(int count) =>
    List.generate(count, (i) => GraphNode(id: 'n$i'));

void main() {
  group('ForceSimulation', () {
    group('initialization', () {
      test('phyllotaxis places nodes without any initial overlap', () {
        final sim = ForceSimulation(nodes: _nodes(150), edges: const []);

        for (var i = 0; i < sim.nodes.length; i++) {
          for (var j = i + 1; j < sim.nodes.length; j++) {
            final a = sim.nodes[i], b = sim.nodes[j];
            expect(
              _distance(a, b),
              greaterThan(a.radius + b.radius),
              reason: 'nodes $i and $j overlap at start',
            );
          }
        }
      });

      test(
        'preset positions are kept (used to carry layout across rebuilds)',
        () {
          final preset = GraphNode(id: 'kept', x: 42, y: -17);
          final sim = ForceSimulation(
            nodes: [
              preset,
              GraphNode(id: 'auto'),
            ],
            edges: const [],
          );

          expect(sim.nodes[0].x, 42);
          expect(sim.nodes[0].y, -17);
          expect(sim.nodes[1].hasPosition, isTrue);
        },
      );

      test('degrees and radii are computed from the edges', () {
        final sim = ForceSimulation(
          nodes: _nodes(3),
          edges: const [GraphEdge(0, 1), GraphEdge(0, 2)],
        );

        expect(sim.nodes[0].degree, 2);
        expect(sim.nodes[1].degree, 1);
        expect(sim.nodes[2].degree, 1);
        expect(sim.nodes[0].radius, closeTo(3 + 1.5 * math.sqrt(2), 1e-9));
        expect(sim.nodes[1].radius, closeTo(4.5, 1e-9));
      });
    });

    group('alpha cooling', () {
      test('tick makes alpha converge below alphaMin, then stops', () {
        final sim = ForceSimulation(
          nodes: _nodes(10),
          edges: const [GraphEdge(0, 1), GraphEdge(1, 2)],
        );

        var ticks = 0;
        while (sim.tick() && ticks < 1000) {
          ticks++;
        }

        expect(sim.alpha, lessThan(sim.alphaMin));
        // alphaDecay is tuned so cooling takes ~300 ticks.
        expect(ticks, inInclusiveRange(250, 350));
        expect(sim.tick(), isFalse, reason: 'a settled sim must stay stopped');
      });

      test('reheat re-warms alpha and restarts the simulation', () {
        final sim = ForceSimulation(nodes: _nodes(5), edges: const []);
        while (sim.tick()) {}
        expect(sim.tick(), isFalse);

        sim.reheat(0.5);

        expect(sim.alpha, 0.5);
        expect(sim.tick(), isTrue);
      });

      test('reheat never cools an already hotter simulation', () {
        final sim = ForceSimulation(nodes: _nodes(5), edges: const []);
        expect(sim.alpha, 1.0);

        sim.reheat(0.5);

        expect(sim.alpha, 1.0);
      });
    });

    group('forces', () {
      test('two linked nodes attract towards the link distance', () {
        final a = GraphNode(id: 'a', x: -100, y: 0);
        final b = GraphNode(id: 'b', x: 100, y: 0);
        final sim = ForceSimulation(
          nodes: [a, b],
          edges: const [GraphEdge(0, 1)],
        );
        expect(_distance(a, b), 200);

        for (var i = 0; i < 300; i++) {
          sim.tick();
        }

        // Measured: settles around ~40 (the link distance).
        expect(_distance(a, b), lessThan(60));
      });

      test('two unlinked nodes repel each other', () {
        final a = GraphNode(id: 'a', x: -25, y: 0);
        final b = GraphNode(id: 'b', x: 25, y: 0);
        // Center force disabled to observe pure many-body repulsion.
        final sim = ForceSimulation(
          nodes: [a, b],
          edges: const [],
          centerStrength: 0,
        );
        expect(_distance(a, b), 50);

        for (var i = 0; i < 100; i++) {
          sim.tick();
        }

        expect(_distance(a, b), greaterThan(50));
      });

      test('center force keeps disconnected nodes near the origin', () {
        final a = GraphNode(id: 'a', x: 500, y: 500);
        final sim = ForceSimulation(nodes: [a], edges: const []);

        for (var i = 0; i < 300; i++) {
          sim.tick();
        }

        expect(a.x.abs(), lessThan(500));
        expect(a.y.abs(), lessThan(500));
      });
    });

    group('Barnes-Hut', () {
      test('approximation matches brute force within tolerance (50 nodes)', () {
        final edges = [for (var i = 0; i < 49; i += 3) GraphEdge(i, i + 1)];
        final barnesHut = ForceSimulation(nodes: _nodes(50), edges: edges);
        // theta 0 disables the aggregate approximation: every interaction is
        // resolved at the leaves, i.e. exact O(N^2) brute force.
        final bruteForce = ForceSimulation(
          nodes: _nodes(50),
          edges: edges,
          theta: 0,
        );

        barnesHut.tick();
        bruteForce.tick();

        // Measured max deviation after one tick: ~0.41 for velocities of up
        // to ~28.6 units/tick (≈1.4% of the strongest force).
        for (var i = 0; i < 50; i++) {
          final dvx = barnesHut.nodes[i].vx - bruteForce.nodes[i].vx;
          final dvy = barnesHut.nodes[i].vy - bruteForce.nodes[i].vy;
          expect(
            math.sqrt(dvx * dvx + dvy * dvy),
            lessThan(0.8),
            reason: 'velocity of node $i deviates too much from brute force',
          );
          expect(
            _distance(barnesHut.nodes[i], bruteForce.nodes[i]),
            lessThan(0.8),
            reason: 'position of node $i deviates too much from brute force',
          );
        }
      });
    });

    group('drag', () {
      test('setDragTarget pins the node and keeps the simulation warm', () {
        final a = GraphNode(id: 'a', x: 0, y: 0);
        final b = GraphNode(id: 'b', x: 30, y: 0);
        final sim = ForceSimulation(
          nodes: [a, b],
          edges: const [GraphEdge(0, 1)],
        );

        sim.setDragTarget(a, 123, -45);
        expect(sim.alphaTarget, ForceSimulation.dragAlphaTarget);
        for (var i = 0; i < 5; i++) {
          expect(sim.tick(), isTrue);
        }

        expect(a.x, 123);
        expect(a.y, -45);
        expect(a.vx, 0);
        expect(a.vy, 0);
        // The free node still reacts to the forces.
        expect(b.x, isNot(30));
      });

      test('a warm drag target keeps a settled simulation ticking', () {
        final sim = ForceSimulation(
          nodes: _nodes(5),
          edges: const [GraphEdge(0, 1)],
        );
        while (sim.tick()) {}
        expect(sim.tick(), isFalse);

        sim.setDragTarget(sim.nodes[0], 10, 10);

        expect(sim.tick(), isTrue);
      });

      test('clearDrag releases the node and lets the simulation cool', () {
        final a = GraphNode(id: 'a', x: 0, y: 0);
        final sim = ForceSimulation(nodes: [a], edges: const []);
        sim.setDragTarget(a, 10, 20);
        sim.tick();

        sim.clearDrag(a);

        expect(a.fx, isNull);
        expect(a.fy, isNull);
        expect(sim.alphaTarget, 0);
      });
    });

    group('determinism', () {
      test('two identical runs produce exactly the same positions', () {
        ForceSimulation build() => ForceSimulation(
          nodes: _nodes(20),
          edges: const [GraphEdge(0, 1), GraphEdge(1, 2), GraphEdge(2, 3)],
        );
        final first = build();
        final second = build();

        for (var i = 0; i < 200; i++) {
          first.tick();
          second.tick();
        }

        for (var i = 0; i < 20; i++) {
          expect(first.nodes[i].x, second.nodes[i].x);
          expect(first.nodes[i].y, second.nodes[i].y);
          expect(first.nodes[i].vx, second.nodes[i].vx);
          expect(first.nodes[i].vy, second.nodes[i].vy);
        }
      });
    });
  });
}
