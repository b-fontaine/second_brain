# Graph visualization in Flutter for Obsidian-style force-directed note graph (100-2000 nodes, pan/zoom/tap, mobile+desktop)

## Recommandation

Custom CustomPainter + own d3-force-style simulation (velocity integration with alpha cooling, spring links, Barnes-Hut repulsion). Zero third-party dependencies. Fallback package if a library is mandated: flutter_graph_view ^2.1.0 (pub.dev, verified publisher dudu.ltd). Do NOT use graphview ^1.5.1 for this use case (tree/hierarchy-oriented, O(N^2) FR layout, one widget per node) or flutter_force_directed_graph ^1.0.8 (20 likes, widget-per-node, unproven beyond ~300 nodes) or force_directed_graphview 0.6.2 (unmaintained ~2 years, no node dragging).

## Support plateformes

{"android": true, "ios": true, "windows": true, "linux": true, "macos": true}

## Fallback

If custom code is rejected: flutter_graph_view: ^2.1.0 (requires Dart SDK ^3.8.0). It has built-in force-directed layout (HookeDecorator = springs, CoulombDecorator = repulsion), pan/zoom, tap/hover panels, and runs layout via isolate_manager off the UI thread. API: FlutterGraphWidget(data: {'vertexes': [...], 'edges': [...]}, convertor: MapConvertor(), algorithm: ForceDirected(decorators: [HookeDecorator(), CoulombDecorator(), ForceMotionDecorator(), TimeCounterDecorator()]), options: Options()..graphStyle = GraphStyle()). Caveats: idiosyncratic API, docs partly Chinese, look-and-feel harder to match to Obsidian, ~2000 nodes untested. For tiny graphs (<150 nodes) graphview: ^1.5.1 with FruchtermanReingoldAlgorithm wrapped in InteractiveViewer also works but layout is one-shot, not a live simulation.

## Entrées pubspec

- `(custom approach: no new dependencies — dart:ui, dart:math, flutter/material only)`
- `# fallback only, if a package is mandated: flutter_graph_view: ^2.1.0`
- `# small-graph alternative (<150 nodes, not recommended here): graphview: ^1.5.1`
- `# evaluated and rejected: flutter_force_directed_graph: ^1.0.8`
- `# evaluated and rejected (unmaintained): force_directed_graphview: ^0.6.2`

## Setup plateforme

Custom approach: none. No permissions, no platform config, no Info.plist/AndroidManifest changes. Works on any Flutter 3.x stable; pure Canvas + gestures. Desktop scroll-zoom needs Listener/PointerScrollEvent (available since Flutter 1.x, nothing to configure). If the flutter_graph_view fallback is chosen instead: requires Dart SDK ^3.8.0 (Flutter 3.32+); no other platform setup.

## Notes API

EVALUATION SUMMARY (all versions verified on pub.dev 2026-07-14):

1) graphview 1.5.1 (published ~8 months ago, 514 likes, 130 pts, 35.8k downloads, MIT, author nabil6391). Layouts: BuchheimWalker (tree), Sugiyama (layered), FruchtermanReingold (force). Actively maintained again after a 3-year gap (1.2.0 -> 1.5.0). BUT: every node is a full Flutter widget (GraphView.builder builds one widget per node), FR layout is O(N^2+E) per iteration and effectively one-shot (settles, no live molecular wobble), no built-in pan/zoom ("must be used together with a Zoom Engine like InteractiveViewer" per README). Community reports it "works excellent with small graphs" only. Rejected for 100-2000 nodes.

2) flutter_force_directed_graph 1.0.8 (published ~10 months ago, 20 likes, 150 pts, ~429 downloads/wk, BSD-3, repo SkywalkerDarren/flutter_force_directed_graph, 14 stars, 5 open issues). Nicest API of the packages: ForceDirectedGraphController<T> + ForceDirectedGraphWidget(nodesBuilder:, edgesBuilder:) with built-in pan/zoom/node-drag/tap. BUT widget-per-node rendering and tiny community; risky for >300 nodes. Rejected as primary.

3) flutter_graph_view 2.1.0 (published ~7 months ago, 91 likes, 160 pts, verified publisher dudu.ltd, Apache-2.0, SDK ^3.8.0). Deps: vector_math ^2.2.0, isolate_manager ^6.1.2, intl ^0.20.2 (2.x dropped the Flame engine dependency that 1.x had — verified in pubspec.yaml on GitHub master). Force layout via decorator pipeline (Hooke/Coulomb/ForceMotion/Pause/Persistence decorators), pan/zoom/hover/tap built-in, layout computed in isolates. Best package option; kept as fallback.

4) force_directed_graphview 0.6.2 (published ~2 years ago, 9 likes). FR layout, InteractiveViewer-based pan/zoom, explicitly NO node dragging. Stale. Rejected.

RECOMMENDED: CUSTOM IMPLEMENTATION (effort: 2-4 dev-days for production quality). This is how Obsidian-class graphs are built; single-canvas painting trivially handles 2000 nodes + 3000 edges at 60fps on phones, and you own the aesthetic (glow, dimming, hover halos).

=== ARCHITECTURE ===
Three files, ~600 lines total:
- graph_simulation.dart: pure Dart force simulation (no Flutter imports except foundation) — testable.
- graph_painter.dart: CustomPainter drawing edges+nodes+labels in one canvas pass.
- graph_view_screen.dart: stateful widget owning Ticker, gestures, viewport transform, selection.

=== SIMULATION (d3-force port, velocity integration + alpha cooling) ===
Use d3-force semantics (simpler and better-tuned than raw Fruchterman-Reingold; no dt, per-tick units):

class GraphNode {
  final String id;
  double x = 0, y = 0, vx = 0, vy = 0;
  double? fx, fy;            // fixed position while dragging
  int degree = 0;
  double radius = 4;         // scale by degree: 3 + sqrt(degree)*1.5
}
class GraphEdge { final int a, b; }   // indices into nodes list

class ForceSimulation {
  final List<GraphNode> nodes; final List<GraphEdge> edges;
  double alpha = 1.0, alphaMin = 0.001, alphaTarget = 0.0;
  final double alphaDecay = 1 - math.pow(0.001, 1 / 300) as double; // ~0.0228
  final double velocityDecay = 0.4;   // friction
  // tuning: repulsionStrength -30..-80 (more negative = more spread),
  // linkDistance 40, linkStrengthFn = 1/min(degA,degB), centerStrength 0.05

  bool tick() {
    if (alpha < alphaMin && alphaTarget == 0) return false; // settled — stop ticker
    alpha += (alphaTarget - alpha) * alphaDecay;
    _applyManyBody();   // Barnes-Hut repulsion, O(N log N)
    _applyLinks();      // springs along edges
    _applyCenter();     // weak pull to origin
    for (final n in nodes) {
      if (n.fx != null) { n.x = n.fx!; n.y = n.fy!; n.vx = 0; n.vy = 0; continue; }
      n.vx *= (1 - velocityDecay); n.vy *= (1 - velocityDecay);
      n.x += n.vx; n.y += n.vy;
    }
    return true;
  }
}

Initial positions — phyllotaxis spiral (deterministic, no overlap, same as d3):
for (i, n) in nodes.indexed:
  final r = 10.0 * math.sqrt(0.5 + i); final a = i * 2.399963229728653; // golden angle
  n.x = r * math.cos(a); n.y = r * math.sin(a);

Link force (per tick):
for (final e in edges) {
  final s = nodes[e.a], t = nodes[e.b];
  var dx = (t.x + t.vx) - (s.x + s.vx), dy = (t.y + t.vy) - (s.y + s.vy);
  var len = math.sqrt(dx*dx + dy*dy); if (len < 1e-6) { dx = 0.1; len = 0.1; }
  final strength = 1 / math.min(s.degree, t.degree).clamp(1, 1 << 30); // dampens hubs
  final l = (len - linkDistance) / len * alpha * strength;
  final biasT = s.degree / (s.degree + t.degree); // heavier node moves less
  t.vx -= dx * l * biasT;      t.vy -= dy * l * biasT;
  s.vx += dx * l * (1 - biasT); s.vy += dy * l * (1 - biasT);
}

Many-body repulsion — Barnes-Hut quadtree (REQUIRED above ~400 nodes; brute force O(N^2) = 4M pairs at 2000 nodes):
- Build quadtree over node positions each tick (cheap: ~1ms for 2000 nodes in AOT Dart).
- Each internal node stores aggregate charge (sum of strengths) and center of mass.
- For each node, walk the tree; if quadWidth / distance < theta (theta = 0.9), apply the aggregated force and skip children:
  final w = quad.size, dx = quad.cx - n.x, dy = quad.cy - n.y; final d2 = dx*dx+dy*dy;
  if (w*w / (theta*theta) < d2) { final f = quad.charge * alpha / d2; n.vx -= dx*f; n.vy -= dy*f; skipSubtree; }
  else recurse; leaves apply exact pairwise force (clamp d2 to min ~ (2*radius)^2 to avoid explosion).
- charge per node: -30.0 * (1 + n.degree * 0.5) gives the molecular look (hubs push harder).

Center force: n.vx += (0 - n.x) * 0.05 * alpha (keeps disconnected clusters on screen). Optionally add collision force (radius+2 padding) for cleaner molecular packing — iterate quadtree same way.

Reheat on interaction (this is what makes it feel alive, exactly like Obsidian):
- onDragStart(node): sim.alphaTarget = 0.3; node.fx = node.x; node.fy = node.y; ensure ticker running.
- onDragUpdate: node.fx/fy = graph-space pointer position.
- onDragEnd: sim.alphaTarget = 0.0; node.fx = node.fy = null.
- On graph data change (note added/linked): sim.alpha = math.max(sim.alpha, 0.5).

=== WIDGET STRUCTURE ===
class GraphViewScreen extends StatefulWidget ... with SingleTickerProviderStateMixin {
  late final Ticker _ticker;               // createTicker((_) { if (!sim.tick()) _ticker.stop(); _repaint.value++; })
  final ValueNotifier<int> _repaint = ValueNotifier(0); // painter repaint signal — NO setState per frame
  double _scale = 1.0; Offset _pan = Offset.zero;       // viewport transform (screen = graph*scale + pan)
  GraphNode? _dragged; String? _selectedId;
}

build():
Listener(                                   // desktop scroll-wheel zoom
  onPointerSignal: (e) { if (e is PointerScrollEvent) _zoomAt(e.localPosition, e.scrollDelta.dy < 0 ? 1.1 : 1/1.1); },
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapUp: (d) => _selectAt(d.localPosition),
    onScaleStart: (d) {                     // scale gesture family covers 1-finger pan + 2-finger pinch + mouse drag
      _dragged = _hitTest(d.localFocalPoint);
      if (_dragged != null) { sim.alphaTarget = .3; _startTicker(); _dragged!..fx=_dragged!.x..fy=_dragged!.y; }
      _startPan = _pan; _startScale = _scale; _startFocal = d.localFocalPoint;
    },
    onScaleUpdate: (d) {
      if (_dragged != null) { final g = _toGraph(d.localFocalPoint); _dragged!..fx=g.dx..fy=g.dy; }
      else {
        _scale = (_startScale * d.scale).clamp(0.05, 4.0);
        _pan = d.localFocalPoint - (_startFocal - _startPan) * (_scale / _startScale); // keep focal point stable
      }
      _repaint.value++;
    },
    onScaleEnd: (_) { if (_dragged != null) { sim.alphaTarget = 0; _dragged!..fx=null..fy=null; _dragged = null; } },
    child: RepaintBoundary(
      child: CustomPaint(size: Size.infinite, painter: GraphPainter(sim, _scale, _pan, _selectedId, repaint: _repaint)),
    ),
  ),
)

Coordinate transforms (all hit-testing in graph space):
Offset _toGraph(Offset screen) => (screen - _pan) / _scale;
GraphNode? _hitTest(Offset screen) { final g = _toGraph(screen); /* linear scan or quadtree; nearest node with dist < node.radius + 12/_scale (bigger touch slop on mobile) */ }
void _zoomAt(Offset focal, double f) { final g = _toGraph(focal); _scale = (_scale*f).clamp(.05, 4); _pan = focal - g * _scale; _repaint.value++; }
_selectAt: hitTest; if node found set _selectedId and call widget.onNodeSelected(id) (open the note); else clear selection.

IMPORTANT: do NOT use InteractiveViewer here. It fights with node-drag gestures (both claim the pan gesture), requires a finite child size, and you need the inverse transform for hit-testing anyway. Own transform = ~20 lines and full control. (If you skip node dragging entirely, InteractiveViewer + TransformationController is acceptable: wrap CustomPaint sized to graph bounds, hit-test with controller.toScene(tapPos).)

=== PAINTER ===
class GraphPainter extends CustomPainter {
  GraphPainter(this.sim, this.scale, this.pan, this.selectedId, {required Listenable repaint}) : super(repaint: repaint);
  @override void paint(Canvas canvas, Size size) {
    canvas.translate(pan.dx, pan.dy); canvas.scale(scale);
    final visible = Rect.fromLTWH(-pan.dx/scale, -pan.dy/scale, size.width/scale, size.height/scale).inflate(50);
    // 1) edges: one Path, single stroke — fastest way to draw thousands of lines
    final path = Path();
    for (final e in sim.edges) { final a = sim.nodes[e.a], b = sim.nodes[e.b];
      if (!visible.contains(Offset(a.x,a.y)) && !visible.contains(Offset(b.x,b.y))) continue;
      path.moveTo(a.x, a.y); path.lineTo(b.x, b.y); }
    canvas.drawPath(path, Paint()..style=PaintingStyle.stroke..strokeWidth=1/scale..color=edgeColor.withOpacity(.35));
    // highlight edges of selected node with a second brighter path
    // 2) nodes: drawCircle per node (2000 drawCircle calls are fine); selected/neighbors brighter, others dimmed
    for (final n in sim.nodes) { if (!visible.contains(Offset(n.x,n.y))) continue;
      canvas.drawCircle(Offset(n.x,n.y), n.radius, paintFor(n)); }
    // 3) labels: ONLY when scale > 0.7 and node visible; cache TextPainters in a Map<String,TextPainter> keyed by id — building 2000 TextPainters per frame will kill you. Fade labels in with opacity = ((scale-0.7)*3).clamp(0,1).
  }
  @override bool shouldRepaint(old) => true; // repaint driven by the Listenable; return true is fine
}

=== PERFORMANCE CHECKLIST (100-2000 nodes) ===
- Single CustomPaint, repaint: Listenable (ValueNotifier bumped by Ticker) — never setState per frame.
- Barnes-Hut theta=0.9 repulsion: 2000-node tick ~2-4ms in AOT Dart on a mid phone. Profile mode, not debug, for judging perf.
- Stop the Ticker when tick() returns false (alpha settled) — zero cost at rest; restart on drag/zoom-reheat/data change.
- Viewport culling for nodes/labels; edges batched in one Path.
- Cache label TextPainters; draw labels only above a zoom threshold; optionally only for selected node's neighborhood.
- If simulation ever janks at the top end, move ForceSimulation into an Isolate: send edges once, receive Float32List(2*N) positions per tick (transferable), keep painting on main isolate. Not needed below ~3000 nodes; do NOT start with this complexity.
- strokeWidth and hit-slop divided by scale so visuals stay constant-weight while zooming.

=== SELECTION UX (Obsidian parity) ===
Tap node -> select: brighten node + its edges + 1-hop neighbors, dim everything else to ~25% opacity (precompute neighbor sets Map<int, Set<int>> once per graph build). Tap empty space -> deselect. Double-tap node -> callback to open the note. Hover (desktop): MouseRegion + onHover hit-test, show label tooltip. Node radius = 3 + 1.5*sqrt(inboundLinks) matches Obsidian sizing.
