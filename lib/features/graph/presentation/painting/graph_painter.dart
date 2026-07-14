import 'package:flutter/material.dart';

import '../../domain/simulation/force_simulation.dart';

/// Mutable viewport transform (`screen = graph * scale + pan`).
///
/// Shared by reference between the gesture layer and [GraphPainter], so pans
/// and zooms only bump the repaint [Listenable] — no widget rebuild per frame.
class GraphViewport {
  double scale = 1.0;
  Offset pan = Offset.zero;

  Offset toGraph(Offset screen) => (screen - pan) / scale;

  Offset toScreen(Offset graph) => graph * scale + pan;
}

/// Colors used by [GraphPainter], resolved from the app [ColorScheme].
class GraphPalette {
  const GraphPalette({
    required this.node,
    required this.edge,
    required this.label,
    required this.highlight,
  });

  factory GraphPalette.fromScheme(ColorScheme scheme) => GraphPalette(
    node: scheme.primary,
    edge: scheme.onSurfaceVariant,
    label: scheme.onSurface,
    highlight: scheme.tertiary,
  );

  final Color node;
  final Color edge;
  final Color label;
  final Color highlight;
}

/// Paints the whole graph (edges, nodes, labels) in a single canvas pass.
///
/// Repaints are driven by the [Listenable] passed as `repaint` (a
/// ValueNotifier bumped by the page ticker) — never by setState.
class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.simulation,
    required this.viewport,
    required this.palette,
    required this.labels,
    required this.labelCache,
    required Listenable repaint,
    this.selectedIndex,
    this.highlighted = const <int>{},
  }) : super(repaint: repaint);

  final ForceSimulation simulation;
  final GraphViewport viewport;
  final GraphPalette palette;

  /// Node id -> title, for labels.
  final Map<String, String> labels;

  /// TextPainter cache keyed by node id, owned by the page state so it
  /// survives painter re-instantiations. Building thousands of TextPainters
  /// per frame would kill performance.
  final Map<String, TextPainter> labelCache;

  /// Index of the selected node, or null.
  final int? selectedIndex;

  /// Selected node + its 1-hop neighbors (precomputed by the page).
  final Set<int> highlighted;

  /// Labels appear when zoomed in beyond this scale, with a fade-in.
  static const double _labelZoomThreshold = 0.7;

  /// Opacity factor applied to everything outside the selection halo.
  static const double _dimFactor = 0.25;

  static const double _edgeOpacity = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = viewport.scale;
    final pan = viewport.pan;
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(scale);
    // Visible rect in graph space, inflated for partially visible items.
    final visible = Rect.fromLTWH(
      -pan.dx / scale,
      -pan.dy / scale,
      size.width / scale,
      size.height / scale,
    ).inflate(50);

    _paintEdges(canvas, visible, scale);
    _paintNodes(canvas, visible, scale);
    if (scale > _labelZoomThreshold) _paintLabels(canvas, visible, scale);
  }

  void _paintEdges(Canvas canvas, Rect visible, double scale) {
    final selected = selectedIndex;
    // All regular edges in a single path with a single stroke: the fastest
    // way to draw thousands of lines.
    final regular = Path();
    final incident = Path();
    for (final e in simulation.edges) {
      final a = simulation.nodes[e.a], b = simulation.nodes[e.b];
      // Cull with the segment's bounding box, not endpoint containment:
      // an edge crossing the viewport must be drawn even when both of its
      // endpoints are off-screen.
      if (!edgeMayBeVisible(visible, Offset(a.x, a.y), Offset(b.x, b.y))) {
        continue;
      }
      final path = selected != null && (e.a == selected || e.b == selected)
          ? incident
          : regular;
      path.moveTo(a.x, a.y);
      path.lineTo(b.x, b.y);
    }
    final dimmed = selected != null;
    canvas.drawPath(
      regular,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / scale
        ..color = palette.edge.withValues(
          alpha: dimmed ? _edgeOpacity * _dimFactor : _edgeOpacity,
        ),
    );
    if (dimmed) {
      canvas.drawPath(
        incident,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale
          ..color = palette.highlight.withValues(alpha: 0.9),
      );
    }
  }

  /// Whether the segment [a]-[b] may cross [visible]. Conservative
  /// bounding-box test: never culls a visible edge, may keep an edge whose
  /// segment passes just outside a corner of the viewport.
  @visibleForTesting
  static bool edgeMayBeVisible(Rect visible, Offset a, Offset b) =>
      visible.overlaps(Rect.fromPoints(a, b));

  void _paintNodes(Canvas canvas, Rect visible, double scale) {
    final selected = selectedIndex;
    final paint = Paint();
    for (var i = 0; i < simulation.nodes.length; i++) {
      final n = simulation.nodes[i];
      final center = Offset(n.x, n.y);
      if (!visible.contains(center)) continue;
      final isSelected = i == selected;
      var color = isSelected ? palette.highlight : palette.node;
      if (selected != null && !highlighted.contains(i)) {
        color = color.withValues(alpha: _dimFactor);
      }
      if (isSelected) {
        canvas.drawCircle(
          center,
          n.radius + 4 / scale,
          Paint()..color = palette.highlight.withValues(alpha: 0.25),
        );
      }
      canvas.drawCircle(center, n.radius, paint..color = color);
    }
  }

  void _paintLabels(Canvas canvas, Rect visible, double scale) {
    final fade = ((scale - _labelZoomThreshold) * 3).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final selected = selectedIndex;
    // Fade-in applied to the whole label layer at once (cached TextPainters
    // have a fixed color, so per-label alpha would defeat the cache).
    final needsLayer = fade < 1.0;
    if (needsLayer) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: fade),
      );
    }
    for (var i = 0; i < simulation.nodes.length; i++) {
      final n = simulation.nodes[i];
      if (!visible.contains(Offset(n.x, n.y))) continue;
      // With an active selection, only the highlighted neighborhood keeps
      // its labels (the rest of the graph is dimmed anyway).
      if (selected != null && !highlighted.contains(i)) continue;
      final tp = _labelPainter(n.id);
      if (tp == null) continue;
      tp.paint(canvas, Offset(n.x - tp.width / 2, n.y + n.radius + 2));
    }
    if (needsLayer) canvas.restore();
  }

  TextPainter? _labelPainter(String id) {
    final cached = labelCache[id];
    if (cached != null) return cached;
    final text = labels[id];
    if (text == null || text.isEmpty) return null;
    final tp = TextPainter(
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
    )..layout(maxWidth: 120);
    labelCache[id] = tp;
    return tp;
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
