import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/presentation/widgets/zettel_mini_constellation.dart';

void main() {
  const center = MiniConstellationNode(
    id: '20260101120000',
    title: 'Concept A',
    degree: 2,
  );
  const neighborB = MiniConstellationNode(
    id: '20260202120000',
    title: 'Concept B',
    degree: 1,
  );
  const neighborC = MiniConstellationNode(
    id: '20260303120000',
    title: 'Concept C',
    degree: 4,
  );

  group('neighborPositions', () {
    test('is deterministic, first neighbor at the top, all on the circle',
        () {
      const size = Size(400, 140);
      final positions = ZettelMiniConstellation.neighborPositions(size, 4);

      expect(positions, hasLength(4));
      expect(
        positions,
        ZettelMiniConstellation.neighborPositions(size, 4),
        reason: 'the layout must be a pure function of its inputs',
      );
      // First neighbor straight above the center.
      expect(positions.first.dx, moreOrLessEquals(200));
      expect(positions.first.dy, lessThan(70));
      // Every neighbor sits at the same distance from the center.
      final centerPoint = size.center(Offset.zero);
      final radius = (positions.first - centerPoint).distance;
      for (final position in positions) {
        expect(
          (position - centerPoint).distance,
          moreOrLessEquals(radius, epsilon: 0.001),
        );
      }
    });

    test('returns nothing for zero neighbors', () {
      expect(
        ZettelMiniConstellation.neighborPositions(const Size(400, 140), 0),
        isEmpty,
      );
    });
  });

  test('radiusFor grows with the degree (Explorer formula)', () {
    expect(ZettelMiniConstellation.radiusFor(0), 3.0);
    expect(ZettelMiniConstellation.radiusFor(4), 6.0);
    expect(
      ZettelMiniConstellation.radiusFor(9),
      greaterThan(ZettelMiniConstellation.radiusFor(4)),
    );
  });

  group('widget', () {
    Future<void> pumpConstellation(
      WidgetTester tester, {
      required List<MiniConstellationNode> neighbors,
      ValueChanged<String>? onNeighborTap,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: ZettelMiniConstellation(
                  center: center,
                  neighbors: neighbors,
                  onNeighborTap: onNeighborTap,
                ),
              ),
            ),
          ),
        ),
      );
      // Must terminate: the mini-constellation is static (no ticker, no
      // repaint listenable) so pumpAndSettle never hangs.
      await tester.pumpAndSettle();
    }

    testWidgets('renders a bounded static canvas', (tester) async {
      await pumpConstellation(tester, neighbors: const [neighborB, neighborC]);

      final canvas = find.byKey(const Key('mini-constellation-canvas'));
      expect(canvas, findsOneWidget);
      expect(
        tester.getSize(canvas).height,
        ZettelMiniConstellation.height,
      );
      // Static layout: nothing left animating after a single frame.
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('tapping a neighbor node reports its id', (tester) async {
      String? tapped;
      await pumpConstellation(
        tester,
        neighbors: const [neighborB, neighborC],
        onNeighborTap: (id) => tapped = id,
      );

      final canvas = find.byKey(const Key('mini-constellation-canvas'));
      final topLeft = tester.getTopLeft(canvas);
      final size = tester.getSize(canvas);
      final positions = ZettelMiniConstellation.neighborPositions(size, 2);
      await tester.tapAt(topLeft + positions.first);

      expect(tapped, neighborB.id);
    });

    testWidgets('tapping empty space reports nothing', (tester) async {
      String? tapped;
      await pumpConstellation(
        tester,
        neighbors: const [neighborB],
        onNeighborTap: (id) => tapped = id,
      );

      final canvas = find.byKey(const Key('mini-constellation-canvas'));
      await tester.tapAt(tester.getTopLeft(canvas) + const Offset(4, 4));

      expect(tapped, isNull);
    });
  });
}
