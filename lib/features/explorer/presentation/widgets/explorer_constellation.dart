import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
// Cross-feature imports — documented exception: the Explorer surface is the
// fusion of the notes list and the graph constellation (chantier 2 of the
// « La Serre » plan); it composes the engine exposed by the graph feature.
import '../../../graph/domain/simulation/force_simulation.dart';
import '../../../graph/presentation/bloc/graph_cubit.dart';
import '../../../graph/presentation/bloc/graph_state.dart';
import '../../../graph/presentation/painting/graph_painter.dart';

/// Full-screen force-directed constellation of the Explorer surface.
///
/// Hosts the existing graph engine — a single [CustomPaint] over the shared
/// [ForceSimulation], viewport and TextPainter cache — and forwards user
/// intents to the [GraphCubit] provided above it: a tap selects a node (or
/// clears the selection), a double tap opens the note, pinching/scrolling
/// zooms and reports the scale so the cubit derives the level of detail.
///
/// The interaction state (coral selection ring, dimmed search mode,
/// « fleur » suggestions, canopies) is read from [state] and mapped to
/// painter indices on state emissions — never per frame.
class ExplorerConstellation extends StatefulWidget {
  const ExplorerConstellation({super.key, required this.state});

  /// Loaded graph plus interaction state, owned by the [GraphCubit].
  final GraphLoaded state;

  @override
  State<ExplorerConstellation> createState() => _ExplorerConstellationState();
}

class _ExplorerConstellationState extends State<ExplorerConstellation>
    with SingleTickerProviderStateMixin {
  static const double _minScale = 0.05;
  static const double _maxScale = 4.0;

  /// Touch slop added to node radius for hit-testing, in screen pixels.
  static const double _hitSlop = 12.0;

  late final Ticker _ticker;

  /// Painter repaint signal, bumped once per frame — never setState per
  /// frame.
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  final GraphViewport _viewport = GraphViewport();
  final Map<String, TextPainter> _labelCache = {};

  ForceSimulation? _sim;
  Map<String, String> _labels = const {};
  Map<String, int> _indexById = const {};
  int _appliedRevision = -1;

  GraphPalette? _palette;
  ThemeData? _lastTheme;

  Size _canvasSize = Size.zero;
  bool _viewInitialized = false;

  GraphNode? _dragged;
  Offset _startPan = Offset.zero;
  double _startScale = 1.0;
  Offset _startFocal = Offset.zero;
  Offset? _doubleTapPosition;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    if (!identical(theme, _lastTheme)) {
      _lastTheme = theme;
      _palette = GraphPalette.fromTheme(theme);
      // Label color is baked into the cached TextPainters.
      _clearLabelCache();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    _clearLabelCache();
    super.dispose();
  }

  // --- Simulation lifecycle -------------------------------------------------

  void _onTick(Duration elapsed) {
    final sim = _sim;
    if (sim == null || !sim.tick()) _ticker.stop();
    // One last bump after stopping so the settled frame is painted.
    _repaint.value++;
  }

  void _ensureTicking() {
    if (!_ticker.isActive) _ticker.start();
  }

  /// Rebuilds the simulation from a freshly loaded graph, carrying over the
  /// positions of surviving nodes, then reheats so the layout adapts. The
  /// selection itself lives in the cubit (which already drops vanished ids).
  void _applyGraph(GraphLoaded state) {
    _appliedRevision = state.revision;
    final previous = <String, GraphNode>{
      if (_sim != null)
        for (final n in _sim!.nodes) n.id: n,
    };
    final nodes = <GraphNode>[];
    for (final spec in state.nodes) {
      final node = GraphNode(id: spec.id);
      final old = previous[spec.id];
      if (old != null) {
        node
          ..x = old.x
          ..y = old.y
          ..vx = old.vx
          ..vy = old.vy;
      }
      nodes.add(node);
    }
    final edges = [for (final e in state.edges) GraphEdge(e.source, e.target)];
    final isFirstBuild = _sim == null;
    final sim = ForceSimulation(nodes: nodes, edges: edges);
    if (!isFirstBuild) sim.reheat(0.5);
    _sim = sim;
    _dragged = null; // A dragged node would belong to the old simulation.
    _labels = {for (final spec in state.nodes) spec.id: spec.title};
    _indexById = {
      for (var i = 0; i < state.nodes.length; i++) state.nodes[i].id: i,
    };
    _clearLabelCache();
    if (nodes.isNotEmpty) _ensureTicking();
    _repaint.value++;
  }

  void _clearLabelCache() {
    for (final tp in _labelCache.values) {
      tp.dispose();
    }
    _labelCache.clear();
  }

  /// Maps cubit-side id sets (selection neighborhood, search, suggestions)
  /// to simulation indices. Recomputed on state emissions only — never per
  /// frame.
  Set<int> _mapIdsToIndices(Set<String> ids) {
    if (ids.isEmpty) return const {};
    return {
      for (final id in ids)
        if (_indexById.containsKey(id)) _indexById[id]!,
    };
  }

  // --- Viewport & gestures --------------------------------------------------

  /// Nearest node under [screen] within `radius + 12/scale`, as an index.
  int? _hitTestIndex(Offset screen) {
    final sim = _sim;
    if (sim == null) return null;
    final g = _viewport.toGraph(screen);
    final slop = _hitSlop / _viewport.scale;
    int? best;
    var bestD2 = double.infinity;
    for (var i = 0; i < sim.nodes.length; i++) {
      final n = sim.nodes[i];
      final dx = n.x - g.dx, dy = n.y - g.dy;
      final d2 = dx * dx + dy * dy;
      final reach = n.radius + slop;
      if (d2 <= reach * reach && d2 < bestD2) {
        bestD2 = d2;
        best = i;
      }
    }
    return best;
  }

  void _zoomAt(Offset focal, double factor) {
    final g = _viewport.toGraph(focal);
    _viewport.scale = (_viewport.scale * factor).clamp(_minScale, _maxScale);
    _viewport.pan = focal - g * _viewport.scale;
    _notifyScale();
    _repaint.value++;
  }

  /// Reports the current scale to the cubit, which derives the level of
  /// detail (it only emits when a LOD threshold is crossed).
  void _notifyScale() {
    if (!mounted) return;
    context.read<GraphCubit>().viewScaleChanged(_viewport.scale);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _zoomAt(event.localPosition, event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
    }
  }

  // The scale gesture family covers 1-finger pan, 2-finger pinch, mouse drag
  // and node dragging. InteractiveViewer is deliberately not used: it fights
  // with node-drag gestures and we need the inverse transform anyway.
  void _onScaleStart(ScaleStartDetails details) {
    final sim = _sim;
    if (sim == null) return;
    // Only a single pointer may pick up a node: a two-finger pinch whose
    // focal point lands on a node must stay a zoom. The recognizer re-emits
    // onScaleStart when a second finger lands mid-gesture, which releases
    // any drag engaged by the first finger.
    _releaseDrag();
    if (details.pointerCount <= 1) {
      final index = _hitTestIndex(details.localFocalPoint);
      _dragged = index == null ? null : sim.nodes[index];
      final dragged = _dragged;
      if (dragged != null) {
        sim.setDragTarget(dragged, dragged.x, dragged.y);
        _ensureTicking();
      }
    }
    _startPan = _viewport.pan;
    _startScale = _viewport.scale;
    _startFocal = details.localFocalPoint;
  }

  void _releaseDrag() {
    final sim = _sim;
    final dragged = _dragged;
    if (sim != null && dragged != null) sim.clearDrag(dragged);
    _dragged = null;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final sim = _sim;
    if (sim == null) return;
    // Defensive: never keep dragging a node once a second pointer is down.
    if (details.pointerCount > 1) _releaseDrag();
    final dragged = _dragged;
    if (dragged != null) {
      final g = _viewport.toGraph(details.localFocalPoint);
      sim.setDragTarget(dragged, g.dx, g.dy);
    } else {
      _viewport.scale = (_startScale * details.scale).clamp(
        _minScale,
        _maxScale,
      );
      // Keep the focal point visually stable while pinching.
      _viewport.pan =
          details.localFocalPoint -
          (_startFocal - _startPan) * (_viewport.scale / _startScale);
      _notifyScale();
    }
    _repaint.value++;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _releaseDrag();
  }

  void _onTapUp(TapUpDetails details) {
    final sim = _sim;
    if (sim == null) return;
    final cubit = context.read<GraphCubit>();
    final index = _hitTestIndex(details.localPosition);
    if (index == null) {
      if (widget.state.selectedId != null) unawaited(cubit.selectNode(null));
      return;
    }
    // The cubit exposes the selection (ring, neighbors) and flags nearby
    // « fleurs »; the page reacts through its state.
    unawaited(cubit.selectNode(sim.nodes[index].id));
  }

  void _onDoubleTap() {
    final position = _doubleTapPosition;
    _doubleTapPosition = null;
    if (position == null) return;
    final index = _hitTestIndex(position);
    if (index == null) return;
    context.push(AppRoutes.noteDetail(_sim!.nodes[index].id));
  }

  // --- Build ----------------------------------------------------------------

  /// Screen-reader summary of the canvas, since the painted nodes and
  /// edges are otherwise invisible to assistive technologies.
  String _semanticsLabel(GraphLoaded state) {
    final n = state.noteCount, m = state.linkCount;
    final base =
        'Graphe de $n note${n > 1 ? 's' : ''} '
        'et $m lien${m > 1 ? 's' : ''}';
    final selectedId = state.selectedId;
    final title = selectedId == null ? null : _labels[selectedId];
    return title == null ? base : '$base. Note sélectionnée : $title';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (_appliedRevision != state.revision || _sim == null) _applyGraph(state);
    final palette = _palette ?? GraphPalette.fromTheme(Theme.of(context));
    final selectedId = state.selectedId;
    final selectedIndex = selectedId == null ? null : _indexById[selectedId];
    final highlighted = selectedIndex == null
        ? const <int>{}
        : {selectedIndex, ..._mapIdsToIndices(state.selectedNeighborIds)};
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _canvasSize) {
          _canvasSize = size;
          if (!_viewInitialized && size != Size.zero) {
            // Start with the graph origin at the canvas center.
            _viewport.pan = size.center(Offset.zero);
            _viewInitialized = true;
          }
        }
        return Semantics(
          container: true,
          label: _semanticsLabel(state),
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _onTapUp,
              onDoubleTapDown: (d) => _doubleTapPosition = d.localPosition,
              onDoubleTap: _onDoubleTap,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: ClipRect(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: GraphPainter(
                      simulation: _sim!,
                      viewport: _viewport,
                      palette: palette,
                      labels: _labels,
                      labelCache: _labelCache,
                      canopies: state.canopies,
                      selectedIndex: selectedIndex,
                      highlighted: highlighted,
                      litIndices: _mapIdsToIndices(state.highlightedIds),
                      suggestedIndices: _mapIdsToIndices(state.suggestedIds),
                      repaint: _repaint,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
