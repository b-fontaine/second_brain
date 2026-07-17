import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Cross-feature import — documented exception: GraphPalette is the shared
// theme-to-color resolver of the Explorer constellation (maturity scale with
// a ColorScheme fallback when SerreTokens is absent); the mini 1-hop view
// must stay color-consistent with it.
import '../../../graph/presentation/painting/graph_painter.dart';

/// A node of the [ZettelMiniConstellation]: the note being read or one of
/// its 1-hop neighbors, with the vault-wide degree driving its maturity
/// color and radius.
class MiniConstellationNode extends Equatable {
  const MiniConstellationNode({
    required this.id,
    required this.title,
    required this.degree,
  });

  final String id;
  final String title;

  /// Undirected link count of the note over the whole vault.
  final int degree;

  @override
  List<Object?> get props => [id, title, degree];
}

/// Static 1-hop constellation shown at the head of the reading view: the
/// current note in the center, its neighbors evenly spaced on a circle,
/// straight edges, maturity colors and truncated labels.
///
/// Deliberately NOT the Explorer's force simulation: the layout is a pure
/// deterministic function of the neighbor list and there is zero animation
/// (the BDD harness requires every pumpAndSettle to terminate).
class ZettelMiniConstellation extends StatelessWidget {
  const ZettelMiniConstellation({
    super.key,
    required this.center,
    required this.neighbors,
    this.onNeighborTap,
  });

  /// The note being read (center node).
  final MiniConstellationNode center;

  /// 1-hop neighbors (outgoing links and backlinks, deduplicated).
  final List<MiniConstellationNode> neighbors;

  /// Called with the tapped neighbor's zettel id (open its detail).
  final ValueChanged<String>? onNeighborTap;

  /// Bounded height of the widget.
  static const double height = 140;

  /// At most this many neighbors are drawn, to stay readable on a phone.
  static const int maxNeighbors = 12;

  /// Accepted distance between a tap and a neighbor node center.
  static const double _tapRadius = 24;

  /// Node radius for [degree] links — same formula as the Explorer graph.
  static double radiusFor(int degree) => 3.0 + 1.5 * math.sqrt(degree);

  /// Positions of [count] neighbors on the layout circle of a canvas of
  /// [size]: first at the top, then clockwise. Pure and deterministic so
  /// tap handling and tests recompute the exact same layout.
  static List<Offset> neighborPositions(Size size, int count) {
    final centerPoint = size.center(Offset.zero);
    // Margin keeps the outer nodes and their labels inside the canvas.
    final radius = math.min(size.width, size.height) / 2 - 26;
    return [
      for (var i = 0; i < count; i++)
        centerPoint +
            Offset.fromDirection(
              -math.pi / 2 + 2 * math.pi * i / count,
              radius,
            ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shown = neighbors.take(maxNeighbors).toList();
    final palette = GraphPalette.fromTheme(Theme.of(context));
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, height);
          final positions = neighborPositions(size, shown.length);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) =>
                _handleTap(details.localPosition, shown, positions),
            child: CustomPaint(
              key: const Key('mini-constellation-canvas'),
              size: size,
              painter: _MiniConstellationPainter(
                center: center,
                neighbors: shown,
                positions: positions,
                palette: palette,
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleTap(
    Offset position,
    List<MiniConstellationNode> shown,
    List<Offset> positions,
  ) {
    final onTap = onNeighborTap;
    if (onTap == null) return;
    for (var i = 0; i < shown.length; i++) {
      if ((positions[i] - position).distance <= _tapRadius) {
        onTap(shown[i].id);
        return;
      }
    }
  }
}

class _MiniConstellationPainter extends CustomPainter {
  _MiniConstellationPainter({
    required this.center,
    required this.neighbors,
    required this.positions,
    required this.palette,
  });

  final MiniConstellationNode center;
  final List<MiniConstellationNode> neighbors;
  final List<Offset> positions;
  final GraphPalette palette;

  static const double _edgeOpacity = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final centerPoint = size.center(Offset.zero);
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.edge.withValues(alpha: _edgeOpacity);
    for (final position in positions) {
      canvas.drawLine(centerPoint, position, edgePaint);
    }
    final nodePaint = Paint();
    for (var i = 0; i < neighbors.length; i++) {
      final neighbor = neighbors[i];
      canvas.drawCircle(
        positions[i],
        ZettelMiniConstellation.radiusFor(neighbor.degree),
        nodePaint..color = palette.maturityColor(neighbor.degree),
      );
      _paintLabel(canvas, neighbor.title, positions[i], neighbor.degree);
    }
    // Center node last so it stays above its edges.
    canvas.drawCircle(
      centerPoint,
      ZettelMiniConstellation.radiusFor(center.degree) + 2,
      nodePaint..color = palette.maturityColor(center.degree),
    );
  }

  void _paintLabel(Canvas canvas, String text, Offset position, int degree) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: palette.label.withValues(alpha: 0.85),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 76);
    painter.paint(
      canvas,
      position +
          Offset(
            -painter.width / 2,
            ZettelMiniConstellation.radiusFor(degree) + 2,
          ),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniConstellationPainter oldDelegate) =>
      oldDelegate.center != center ||
      !listEquals(oldDelegate.neighbors, neighbors) ||
      !listEquals(oldDelegate.positions, positions) ||
      oldDelegate.palette.label != palette.label;
}
