import 'package:flutter/material.dart';

import '../../../../core/theme/serre_tokens.dart';
// Cross-feature util import — documented exception: ZettelMaturity is the
// shared maturity scale exposed by the zettel feature (also used by lists
// and badges), so the graph stays consistent with the rest of the app.
import '../../../zettel/presentation/utils/zettel_maturity.dart';
import '../../domain/simulation/force_simulation.dart';
import '../utils/graph_canopy.dart';
import '../utils/graph_lod.dart';

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

/// Colors used by [GraphPainter], resolved from the theme before painting —
/// the painter itself never touches a [BuildContext].
class GraphPalette {
  const GraphPalette({
    required this.pousse,
    required this.feuillage,
    required this.arbre,
    required this.fleur,
    required this.edge,
    required this.label,
    required this.selection,
    required this.canopy,
  });

  /// Reads the « La Serre » tokens; falls back to the [ColorScheme] when the
  /// extension is absent (bare [ThemeData] in tests).
  factory GraphPalette.fromTheme(ThemeData theme) {
    final tokens = theme.extension<SerreTokens>();
    if (tokens == null) {
      final scheme = theme.colorScheme;
      return GraphPalette(
        pousse: scheme.primary,
        feuillage: scheme.primary,
        arbre: scheme.primary,
        fleur: scheme.tertiary,
        edge: scheme.onSurfaceVariant,
        label: scheme.onSurface,
        selection: scheme.tertiary,
        canopy: scheme.primaryContainer,
      );
    }
    return GraphPalette(
      pousse: tokens.pousse,
      feuillage: tokens.feuillage,
      arbre: tokens.arbre,
      fleur: tokens.fleur,
      edge: tokens.sub,
      label: tokens.ink,
      selection: tokens.fleur,
      canopy: tokens.feuillage,
    );
  }

  /// Maturity color: 0-1 links.
  final Color pousse;

  /// Maturity color: 2-3 links.
  final Color feuillage;

  /// Maturity color: 4+ links.
  final Color arbre;

  /// AI-suggested (« fleur ») nodes and their halo.
  final Color fleur;

  final Color edge;
  final Color label;

  /// Coral ring around the selected node and its incident edges.
  final Color selection;

  /// Fill of the tag canopies in the zoomed-out view.
  final Color canopy;

  /// Node color for [degree] incident links, following the maturity scale.
  Color maturityColor(int degree) => switch (ZettelMaturity.of(degree)) {
    ZettelMaturity.pousse => pousse,
    ZettelMaturity.feuillage => feuillage,
    ZettelMaturity.arbre => arbre,
  };
}

/// Paints the whole graph (edges, nodes, labels — or tag canopies when
/// zoomed far out) in a single canvas pass.
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
    this.canopies = const [],
    this.selectedIndex,
    this.highlighted = const <int>{},
    this.litIndices = const <int>{},
    this.suggestedIndices = const <int>{},
  }) : super(repaint: repaint);

  final ForceSimulation simulation;
  final GraphViewport viewport;
  final GraphPalette palette;

  /// Node id -> title, for labels.
  final Map<String, String> labels;

  /// TextPainter cache keyed by node id (and by a `canopy:` prefixed key for
  /// canopy captions), owned by the page state so it survives painter
  /// re-instantiations. Building thousands of TextPainters per frame would
  /// kill performance.
  final Map<String, TextPainter> labelCache;

  /// Tag canopies shown in [GraphLod.canopy] mode. Membership is
  /// precomputed per graph revision; only centroids are derived from the
  /// live positions at paint time.
  final List<GraphCanopy> canopies;

  /// Index of the selected node, or null.
  final int? selectedIndex;

  /// Selected node + its 1-hop neighbors (precomputed by the page).
  final Set<int> highlighted;

  /// Search mode: node indices kept lit; everything else (nodes and edges)
  /// is dimmed. Empty means normal mode.
  final Set<int> litIndices;

  /// « Fleur » nodes: AI suggestions, drawn in coral with a light halo.
  final Set<int> suggestedIndices;

  /// Opacity factor applied to everything outside the selection halo or the
  /// lit search set.
  static const double _dimFactor = 0.25;

  static const double _edgeOpacity = 0.35;
  static const double _canopyFillOpacity = 0.30;
  static const double _canopyStrokeOpacity = 0.55;
  static const double _suggestionHaloOpacity = 0.18;

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

    if (GraphLod.forScale(scale) == GraphLod.canopy) {
      _paintCanopies(canvas, visible, scale);
      return;
    }
    _paintEdges(canvas, visible, scale);
    _paintNodes(canvas, visible, scale);
    _paintLabels(canvas, visible, scale);
  }

  // --- Canopies (zoomed-out semantic view) ----------------------------------

  void _paintCanopies(Canvas canvas, Rect visible, double scale) {
    final fill = Paint()
      ..color = palette.canopy.withValues(alpha: _canopyFillOpacity);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / scale
      ..color = palette.canopy.withValues(alpha: _canopyStrokeOpacity);
    for (final canopy in canopies) {
      if (canopy.memberIndices.isEmpty) continue;
      final center = GraphCanopy.centroidOf(
        canopy.memberIndices,
        simulation.nodes,
      );
      final radius = canopy.radius;
      if (!visible.overlaps(Rect.fromCircle(center: center, radius: radius))) {
        continue;
      }
      canvas.drawCircle(center, radius, fill);
      canvas.drawCircle(center, radius, stroke);
      final tp = _canopyLabelPainter(canopy);
      // Caption at constant screen size, whatever the zoom.
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1 / scale);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  TextPainter _canopyLabelPainter(GraphCanopy canopy) {
    // Node ids are 14-digit timestamps: the prefix can never collide. The
    // count is part of the key so a membership change never reuses a stale
    // caption (the cache is also cleared on every graph revision).
    final key = 'canopy:${canopy.label}·${canopy.count}';
    final cached = labelCache[key];
    if (cached != null) return cached;
    final tp = TextPainter(
      text: TextSpan(
        text: canopy.displayLabel,
        style: TextStyle(
          color: palette.label,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 160);
    labelCache[key] = tp;
    return tp;
  }

  // --- Edges -----------------------------------------------------------------

  void _paintEdges(Canvas canvas, Rect visible, double scale) {
    final selected = selectedIndex;
    final searchActive = litIndices.isNotEmpty;
    // Edges are batched per style in a single path with a single stroke:
    // the fastest way to draw thousands of lines.
    final regular = Path();
    final dimmed = Path();
    final incident = Path();
    for (final e in simulation.edges) {
      final a = simulation.nodes[e.a], b = simulation.nodes[e.b];
      // Cull with the segment's bounding box, not endpoint containment:
      // an edge crossing the viewport must be drawn even when both of its
      // endpoints are off-screen.
      if (!edgeMayBeVisible(visible, Offset(a.x, a.y), Offset(b.x, b.y))) {
        continue;
      }
      final Path path;
      if (selected != null && (e.a == selected || e.b == selected)) {
        path = incident;
      } else {
        // With a selection, everything outside its halo is dimmed; in
        // search mode only edges joining two lit nodes stay bright.
        final isDimmed =
            selected != null ||
            (searchActive &&
                !(litIndices.contains(e.a) && litIndices.contains(e.b)));
        path = isDimmed ? dimmed : regular;
      }
      path.moveTo(a.x, a.y);
      path.lineTo(b.x, b.y);
    }
    canvas.drawPath(
      regular,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / scale
        ..color = palette.edge.withValues(alpha: _edgeOpacity),
    );
    canvas.drawPath(
      dimmed,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / scale
        ..color = palette.edge.withValues(alpha: _edgeOpacity * _dimFactor),
    );
    if (selected != null) {
      canvas.drawPath(
        incident,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale
          ..color = palette.selection.withValues(alpha: 0.9),
      );
    }
  }

  /// Whether the segment [a]-[b] may cross [visible]. Conservative
  /// bounding-box test: never culls a visible edge, may keep an edge whose
  /// segment passes just outside a corner of the viewport.
  @visibleForTesting
  static bool edgeMayBeVisible(Rect visible, Offset a, Offset b) =>
      visible.overlaps(Rect.fromPoints(a, b));

  // --- Nodes -----------------------------------------------------------------

  void _paintNodes(Canvas canvas, Rect visible, double scale) {
    final selected = selectedIndex;
    final searchActive = litIndices.isNotEmpty;
    final paint = Paint();
    for (var i = 0; i < simulation.nodes.length; i++) {
      final n = simulation.nodes[i];
      final center = Offset(n.x, n.y);
      if (!visible.contains(center)) continue;
      final isSelected = i == selected;
      final isSuggested = suggestedIndices.contains(i);
      var color = isSuggested ? palette.fleur : palette.maturityColor(n.degree);
      var opacity = 1.0;
      if (selected != null && !highlighted.contains(i)) opacity *= _dimFactor;
      if (searchActive && !litIndices.contains(i) && !isSelected) {
        opacity *= _dimFactor;
      }
      if (opacity < 1) color = color.withValues(alpha: opacity);
      if (isSuggested) {
        // Light halo around AI suggestions.
        canvas.drawCircle(
          center,
          n.radius + 4 / scale,
          Paint()
            ..color = palette.fleur.withValues(
              alpha: _suggestionHaloOpacity * opacity,
            ),
        );
      }
      canvas.drawCircle(center, n.radius, paint..color = color);
      if (isSelected) {
        // Coral selection ring.
        canvas.drawCircle(
          center,
          n.radius + 3 / scale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 / scale
            ..color = palette.selection,
        );
      }
    }
  }

  // --- Labels ----------------------------------------------------------------

  void _paintLabels(Canvas canvas, Rect visible, double scale) {
    // Hub labels fade in when leaving the canopy view; the remaining labels
    // fade in when crossing the detail threshold. Two subsets so each label
    // is painted exactly once with its own fade.
    final hubFade = ((scale - GraphLod.canopyMaxScale) * 3).clamp(0.0, 1.0);
    _paintLabelSubset(canvas, visible, hubsOnly: true, fade: hubFade);
    if (scale > GraphLod.fullLabelsMinScale) {
      final fade = ((scale - GraphLod.fullLabelsMinScale) * 3).clamp(0.0, 1.0);
      _paintLabelSubset(canvas, visible, hubsOnly: false, fade: fade);
    }
  }

  void _paintLabelSubset(
    Canvas canvas,
    Rect visible, {
    required bool hubsOnly,
    required double fade,
  }) {
    if (fade <= 0) return;
    final selected = selectedIndex;
    final searchActive = litIndices.isNotEmpty;
    // Fade applied to the whole subset at once (cached TextPainters have a
    // fixed color, so per-label alpha would defeat the cache).
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
      if ((n.degree >= GraphLod.hubLabelMinDegree) != hubsOnly) continue;
      // With an active selection, only the highlighted neighborhood keeps
      // its labels; in search mode, only the lit nodes do.
      if (selected != null && !highlighted.contains(i)) continue;
      if (searchActive && !litIndices.contains(i) && i != selected) continue;
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
