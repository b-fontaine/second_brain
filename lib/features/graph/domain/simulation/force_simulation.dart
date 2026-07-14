import 'dart:math' as math;

/// A node of the force-directed simulation.
///
/// Positions default to NaN; nodes without a position are laid out on a
/// deterministic phyllotaxis spiral by [ForceSimulation]. Callers may preset
/// [x]/[y] (e.g. to carry positions over when the graph is rebuilt).
class GraphNode {
  GraphNode({required this.id, this.x = double.nan, this.y = double.nan});

  final String id;

  /// Position in graph space.
  double x, y;

  /// Velocity, in graph-space units per tick.
  double vx = 0, vy = 0;

  /// Fixed position while the node is dragged; null otherwise.
  double? fx, fy;

  /// Number of incident edges. Computed by [ForceSimulation].
  int degree = 0;

  /// Obsidian-like sizing: hubs are bigger.
  double get radius => 3.0 + 1.5 * math.sqrt(degree.toDouble());

  bool get hasPosition => !x.isNaN && !y.isNaN;
}

/// An undirected edge between two nodes, referenced by their indices in the
/// simulation node list.
class GraphEdge {
  const GraphEdge(this.a, this.b);

  final int a;
  final int b;
}

/// d3-force style simulation: velocity Verlet integration with alpha cooling,
/// spring link force, Barnes-Hut many-body repulsion and a weak centering
/// force. Pure Dart, fully deterministic (no randomness).
class ForceSimulation {
  ForceSimulation({
    required this.nodes,
    required this.edges,
    this.linkDistance = 40.0,
    this.chargeStrength = -30.0,
    this.centerStrength = 0.05,
    this.theta = 0.9,
    this.distanceMin = 1.0,
  }) {
    _computeDegrees();
    _initializePositions();
    _charges = List<double>.generate(
      nodes.length,
      (i) => chargeStrength * (1 + nodes[i].degree * 0.5),
      growable: false,
    );
    _linkStrengths = List<double>.generate(edges.length, (k) {
      final e = edges[k];
      final minDegree = math.min(nodes[e.a].degree, nodes[e.b].degree);
      return 1.0 / math.max(1, minDegree);
    }, growable: false);
    _linkBias = List<double>.generate(edges.length, (k) {
      final e = edges[k];
      final degA = nodes[e.a].degree, degB = nodes[e.b].degree;
      final total = degA + degB;
      return total == 0 ? 0.5 : degA / total;
    }, growable: false);
  }

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  /// Rest length of the link springs.
  final double linkDistance;

  /// Base many-body charge; per-node charge is
  /// `chargeStrength * (1 + degree * 0.5)` (hubs push harder).
  final double chargeStrength;

  /// Strength of the pull towards the origin.
  final double centerStrength;

  /// Barnes-Hut accuracy criterion; 0 degenerates to exact brute force.
  final double theta;

  /// Repulsion distances below this are softened to avoid explosions.
  final double distanceMin;

  /// Simulation heat: forces are scaled by alpha, which decays each tick.
  double alpha = 1.0;
  double alphaMin = 0.001;

  /// Alpha converges towards this target; used to keep the simulation warm
  /// during interactions (drag reheat).
  double alphaTarget = 0.0;

  /// ~0.0228 — alpha reaches [alphaMin] in about 300 ticks.
  final double alphaDecay = 1 - math.pow(0.001, 1 / 300).toDouble();

  /// Friction applied to velocities each tick.
  final double velocityDecay = 0.4;

  /// Alpha target applied while a node is dragged.
  static const double dragAlphaTarget = 0.3;

  /// Golden angle, for the phyllotaxis initial layout.
  static const double _goldenAngle = 2.399963229728653;

  late final List<double> _charges;
  late final List<double> _linkStrengths;
  late final List<double> _linkBias;

  /// Advances the simulation by one step.
  ///
  /// Returns false without doing any work once alpha has cooled below
  /// [alphaMin] (and no reheat target is set) — the caller should stop its
  /// ticker and restart it on the next interaction.
  bool tick() {
    if (alpha < alphaMin && alphaTarget == 0) return false;
    alpha += (alphaTarget - alpha) * alphaDecay;
    _applyManyBody();
    _applyLinks();
    _applyCenter();
    for (final n in nodes) {
      if (n.fx != null || n.fy != null) {
        n.x = n.fx ?? n.x;
        n.y = n.fy ?? n.y;
        n.vx = 0;
        n.vy = 0;
        continue;
      }
      n.vx *= 1 - velocityDecay;
      n.vy *= 1 - velocityDecay;
      n.x += n.vx;
      n.y += n.vy;
    }
    return true;
  }

  /// Re-warms the simulation so it starts moving again (never cools it).
  void reheat(double alpha) {
    this.alpha = math.max(this.alpha, alpha.clamp(0.0, 1.0));
  }

  /// Pins [node] to (x, y) and keeps the simulation warm while dragging.
  void setDragTarget(GraphNode node, double x, double y) {
    node
      ..fx = x
      ..fy = y;
    if (alphaTarget < dragAlphaTarget) alphaTarget = dragAlphaTarget;
  }

  /// Releases the drag pin on [node] and lets the simulation cool down.
  void clearDrag(GraphNode node) {
    node
      ..fx = null
      ..fy = null;
    alphaTarget = 0.0;
  }

  void _computeDegrees() {
    for (final n in nodes) {
      n.degree = 0;
    }
    for (final e in edges) {
      nodes[e.a].degree++;
      nodes[e.b].degree++;
    }
  }

  /// Deterministic phyllotaxis spiral (same as d3): no initial overlap,
  /// no randomness. Only applied to nodes without a preset position.
  void _initializePositions() {
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      if (n.hasPosition) continue;
      final r = 10.0 * math.sqrt(0.5 + i);
      final a = i * _goldenAngle;
      n.x = r * math.cos(a);
      n.y = r * math.sin(a);
    }
  }

  void _applyLinks() {
    for (var k = 0; k < edges.length; k++) {
      final e = edges[k];
      final s = nodes[e.a], t = nodes[e.b];
      var dx = (t.x + t.vx) - (s.x + s.vx);
      var dy = (t.y + t.vy) - (s.y + s.vy);
      var len = math.sqrt(dx * dx + dy * dy);
      if (len < 1e-6) {
        // Deterministic nudge for coincident endpoints.
        dx = 1e-3;
        dy = 0;
        len = 1e-3;
      }
      final l = (len - linkDistance) / len * alpha * _linkStrengths[k];
      final bias = _linkBias[k];
      t.vx -= dx * l * bias;
      t.vy -= dy * l * bias;
      s.vx += dx * l * (1 - bias);
      s.vy += dy * l * (1 - bias);
    }
  }

  void _applyCenter() {
    for (final n in nodes) {
      n.vx += (0 - n.x) * centerStrength * alpha;
      n.vy += (0 - n.y) * centerStrength * alpha;
    }
  }

  /// Barnes-Hut O(N log N) repulsion. The quadtree is rebuilt every tick
  /// (cheap: ~1ms for 2000 nodes in AOT Dart).
  void _applyManyBody() {
    if (nodes.length < 2) return;
    final root = _QuadCell.build(nodes, _charges);
    if (root == null) return;
    final theta2 = theta * theta;
    final distanceMin2 = distanceMin * distanceMin;
    for (final n in nodes) {
      root.applyTo(n, alpha, theta2, distanceMin2);
    }
  }
}

/// A cell of the Barnes-Hut quadtree. Leaves hold one body (or several when
/// they are coincident or the maximum depth is reached); internal cells hold
/// the aggregated charge and its center of mass.
class _QuadCell {
  _QuadCell(this.x0, this.y0, this.size);

  final double x0, y0, size;

  List<_QuadCell?>? children;
  final List<GraphNode> bodies = [];
  final List<double> bodyCharges = [];

  double charge = 0;
  double comX = 0, comY = 0;

  static const int _maxDepth = 24;

  bool get isLeaf => children == null;

  /// Builds and aggregates the tree for the current node positions.
  static _QuadCell? build(List<GraphNode> nodes, List<double> charges) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final n in nodes) {
      if (n.x < minX) minX = n.x;
      if (n.y < minY) minY = n.y;
      if (n.x > maxX) maxX = n.x;
      if (n.y > maxY) maxY = n.y;
    }
    if (!minX.isFinite || !minY.isFinite) return null;
    var size = math.max(maxX - minX, maxY - minY);
    if (size <= 0) size = 1.0;
    final root = _QuadCell(minX, minY, size);
    for (var i = 0; i < nodes.length; i++) {
      root.insert(nodes[i], charges[i], 0);
    }
    root.accumulate();
    return root;
  }

  void insert(GraphNode node, double nodeCharge, int depth) {
    if (isLeaf) {
      if (bodies.isEmpty) {
        bodies.add(node);
        bodyCharges.add(nodeCharge);
        return;
      }
      final coincident = bodies[0].x == node.x && bodies[0].y == node.y;
      if (depth >= _maxDepth || coincident) {
        bodies.add(node);
        bodyCharges.add(nodeCharge);
        return;
      }
      // Subdivide and push the existing occupants down.
      children = List<_QuadCell?>.filled(4, null);
      for (var i = 0; i < bodies.length; i++) {
        _childFor(bodies[i]).insert(bodies[i], bodyCharges[i], depth + 1);
      }
      bodies.clear();
      bodyCharges.clear();
    }
    _childFor(node).insert(node, nodeCharge, depth + 1);
  }

  _QuadCell _childFor(GraphNode node) {
    final half = size / 2;
    final midX = x0 + half, midY = y0 + half;
    final east = node.x >= midX, south = node.y >= midY;
    final index = (south ? 2 : 0) + (east ? 1 : 0);
    return children![index] ??= _QuadCell(
      east ? midX : x0,
      south ? midY : y0,
      half,
    );
  }

  /// Bottom-up aggregation of charges and centers of mass
  /// (weighted by absolute charge, like d3).
  void accumulate() {
    var total = 0.0, weight = 0.0, wx = 0.0, wy = 0.0;
    if (isLeaf) {
      for (var i = 0; i < bodies.length; i++) {
        final c = bodyCharges[i];
        final w = c.abs();
        total += c;
        weight += w;
        wx += bodies[i].x * w;
        wy += bodies[i].y * w;
      }
    } else {
      for (final child in children!) {
        if (child == null) continue;
        child.accumulate();
        final w = child.charge.abs();
        total += child.charge;
        weight += w;
        wx += child.comX * w;
        wy += child.comY * w;
      }
    }
    charge = total;
    if (weight > 0) {
      comX = wx / weight;
      comY = wy / weight;
    }
  }

  /// Applies the repulsion of this cell to [target], recursing only when the
  /// cell is too close/large for the aggregate approximation.
  void applyTo(
    GraphNode target,
    double alpha,
    double theta2,
    double distanceMin2,
  ) {
    if (charge == 0) return;
    if (!isLeaf) {
      final dx = comX - target.x, dy = comY - target.y;
      final d2 = dx * dx + dy * dy;
      if (size * size < theta2 * d2) {
        _applyPoint(target, comX, comY, charge, alpha, distanceMin2);
        return;
      }
      for (final child in children!) {
        child?.applyTo(target, alpha, theta2, distanceMin2);
      }
      return;
    }
    for (var i = 0; i < bodies.length; i++) {
      if (identical(bodies[i], target)) continue;
      _applyPoint(
        target,
        bodies[i].x,
        bodies[i].y,
        bodyCharges[i],
        alpha,
        distanceMin2,
      );
    }
  }

  static void _applyPoint(
    GraphNode target,
    double px,
    double py,
    double pointCharge,
    double alpha,
    double distanceMin2,
  ) {
    var dx = px - target.x, dy = py - target.y;
    var d2 = dx * dx + dy * dy;
    if (d2 == 0) {
      // Deterministic separation of exactly coincident points.
      dx = 1e-6;
      d2 = 1e-12;
    }
    if (d2 < distanceMin2) d2 = math.sqrt(distanceMin2 * d2);
    final f = pointCharge * alpha / d2;
    target.vx += dx * f;
    target.vy += dy * f;
  }
}
