import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../zettel/domain/entities/zettel_id.dart';
import '../../domain/simulation/force_simulation.dart';
import '../bloc/graph_cubit.dart';
import '../bloc/graph_state.dart';
import '../painting/graph_painter.dart';
import '../widgets/graph_reading_panel.dart';

/// Force-directed ("molecular") view of the zettelkasten. Route: `/graph`.
class GraphPage extends StatelessWidget {
  const GraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GraphCubit>(
      create: (_) => getIt<GraphCubit>()..load(),
      child: const _GraphView(),
    );
  }
}

class _GraphView extends StatefulWidget {
  const _GraphView();

  @override
  State<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<_GraphView>
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
  List<Set<int>> _adjacency = const [];
  Map<String, String> _labels = const {};
  int _appliedRevision = -1;

  GraphPalette? _palette;
  ColorScheme? _lastScheme;

  Size _canvasSize = Size.zero;
  bool _viewInitialized = false;

  GraphNode? _dragged;
  Offset _startPan = Offset.zero;
  double _startScale = 1.0;
  Offset _startFocal = Offset.zero;
  Offset? _doubleTapPosition;

  String? _selectedId;
  int? _selectedIndex;
  Set<int> _highlighted = const {};

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scheme = Theme.of(context).colorScheme;
    if (!identical(scheme, _lastScheme)) {
      _lastScheme = scheme;
      _palette = GraphPalette.fromScheme(scheme);
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
  /// positions of surviving nodes, then reheats so the layout adapts.
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
    _clearLabelCache();
    _adjacency = _buildAdjacency(nodes.length, edges);
    // Re-map the selection by id; drop it if the note disappeared.
    final selectedId = _selectedId;
    if (selectedId != null) {
      final index = state.nodes.indexWhere((n) => n.id == selectedId);
      _selectedIndex = index < 0 ? null : index;
      if (index < 0) _selectedId = null;
    }
    _highlighted = _highlightFor(_selectedIndex);
    _ensureTicking();
    _repaint.value++;
  }

  static List<Set<int>> _buildAdjacency(int count, List<GraphEdge> edges) {
    final adjacency = List.generate(count, (_) => <int>{});
    for (final e in edges) {
      adjacency[e.a].add(e.b);
      adjacency[e.b].add(e.a);
    }
    return adjacency;
  }

  Set<int> _highlightFor(int? selected) {
    if (selected == null) return const {};
    return {selected, ..._adjacency[selected]};
  }

  void _clearLabelCache() {
    for (final tp in _labelCache.values) {
      tp.dispose();
    }
    _labelCache.clear();
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
    _repaint.value++;
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
    }
    _repaint.value++;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _releaseDrag();
  }

  void _onTapUp(TapUpDetails details) {
    final sim = _sim;
    if (sim == null) return;
    final index = _hitTestIndex(details.localPosition);
    if (index == null) {
      _clearSelection();
      return;
    }
    final id = sim.nodes[index].id;
    setState(() {
      _selectedId = id;
      _selectedIndex = index;
      _highlighted = _highlightFor(index);
    });
    if (!Breakpoints.isExpanded(context)) _showReadingSheet(id);
  }

  void _onDoubleTap() {
    final position = _doubleTapPosition;
    _doubleTapPosition = null;
    if (position == null) return;
    final index = _hitTestIndex(position);
    if (index == null) return;
    context.push('/note/${_sim!.nodes[index].id}');
  }

  void _clearSelection() {
    if (_selectedId == null) return;
    setState(() {
      _selectedId = null;
      _selectedIndex = null;
      _highlighted = const {};
    });
  }

  // --- Toolbar actions ------------------------------------------------------

  /// Fits the whole graph into the current canvas.
  void _fitToBounds() {
    final sim = _sim;
    if (sim == null || sim.nodes.isEmpty || _canvasSize == Size.zero) return;
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final n in sim.nodes) {
      if (n.x - n.radius < minX) minX = n.x - n.radius;
      if (n.y - n.radius < minY) minY = n.y - n.radius;
      if (n.x + n.radius > maxX) maxX = n.x + n.radius;
      if (n.y + n.radius > maxY) maxY = n.y + n.radius;
    }
    final bounds = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(40);
    final fit = math.min(
      _canvasSize.width / bounds.width,
      _canvasSize.height / bounds.height,
    );
    _viewport.scale = fit.clamp(_minScale, _maxScale);
    _viewport.pan =
        _canvasSize.center(Offset.zero) - bounds.center * _viewport.scale;
    _repaint.value++;
  }

  /// Re-warms the simulation so the layout reorganizes itself.
  void _reorganize() {
    final sim = _sim;
    if (sim == null) return;
    sim.reheat(1.0);
    _ensureTicking();
  }

  // --- Reading panel --------------------------------------------------------

  Future<void> _showReadingSheet(String id) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            // Slim grab area bound to the sheet controller so the sheet can
            // be dragged even though the panel scrolls its own content.
            SingleChildScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GraphReadingPanel(
                zettelId: ZettelId.fromString(id),
                onClose: () => Navigator.of(sheetContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) _clearSelection();
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GraphCubit, GraphState>(
      builder: (context, state) {
        // No local AppBar: the AdaptiveScaffold shell already titles the
        // tab. Graph actions live in an overlay toolbar on the canvas.
        return Scaffold(
          body: switch (state) {
            GraphInitial() ||
            GraphLoading() => const Center(child: CircularProgressIndicator()),
            GraphLoadFailure(:final message) => _buildFailure(context, message),
            GraphLoaded() => _buildLoaded(context, state),
          },
        );
      },
    );
  }

  static String _counterLabel(GraphLoaded state) {
    final n = state.noteCount, m = state.linkCount;
    return '$n note${n > 1 ? 's' : ''} · $m lien${m > 1 ? 's' : ''}';
  }

  /// Screen-reader summary of the canvas, since the painted nodes and
  /// edges are otherwise invisible to assistive technologies.
  String _semanticsLabel(GraphLoaded state) {
    final n = state.noteCount, m = state.linkCount;
    final base =
        'Graphe de $n note${n > 1 ? 's' : ''} '
        'et $m lien${m > 1 ? 's' : ''}';
    final selectedId = _selectedId;
    final title = selectedId == null ? null : _labels[selectedId];
    return title == null ? base : '$base. Note sélectionnée : $title';
  }

  Widget _buildFailure(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => context.read<GraphCubit>().load(),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, GraphLoaded state) {
    if (_appliedRevision != state.revision || _sim == null) _applyGraph(state);
    final canvas = _buildCanvas(context, state);
    final selectedId = _selectedId;
    if (Breakpoints.isExpanded(context) && selectedId != null) {
      return Row(
        children: [
          Expanded(child: canvas),
          Container(
            width: 400,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: GraphReadingPanel(
              zettelId: ZettelId.fromString(selectedId),
              onClose: _clearSelection,
            ),
          ),
        ],
      );
    }
    return canvas;
  }

  Widget _buildCanvas(BuildContext context, GraphLoaded state) {
    final palette =
        _palette ?? GraphPalette.fromScheme(Theme.of(context).colorScheme);
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
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
                    onDoubleTapDown: (d) =>
                        _doubleTapPosition = d.localPosition,
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
                            selectedIndex: _selectedIndex,
                            highlighted: _highlighted,
                            repaint: _repaint,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(child: _buildToolbar(context, state)),
        ),
        if (state.nodes.isEmpty)
          const Center(child: Text('Aucune note à afficher')),
      ],
    );
  }

  /// Counter and view actions, previously hosted by a page-local AppBar
  /// (removed: the shell AppBar already titles the tab).
  Widget _buildToolbar(BuildContext context, GraphLoaded state) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _counterLabel(state),
                style: theme.textTheme.labelMedium,
              ),
            ),
            IconButton(
              tooltip: 'Recentrer',
              icon: const Icon(Icons.center_focus_strong),
              onPressed: _fitToBounds,
            ),
            IconButton(
              tooltip: 'Réorganiser',
              icon: const Icon(Icons.replay),
              onPressed: _reorganize,
            ),
          ],
        ),
      ),
    );
  }
}
