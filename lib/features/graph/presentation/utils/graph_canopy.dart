import 'dart:ui' show Offset;

import 'package:equatable/equatable.dart';

import '../../domain/simulation/force_simulation.dart';

/// A cluster of nodes sharing the same dominant tag, shown instead of the
/// individual nodes when the view is zoomed far out ([GraphLod.canopy]).
///
/// Membership is precomputed once per graph revision (never per frame); only
/// the centroid depends on the live simulation positions and is recomputed
/// at paint time via [centroidOf] (a single O(N) pass, cheaper than drawing
/// the nodes it replaces).
class GraphCanopy extends Equatable {
  const GraphCanopy({required this.label, required this.memberIndices});

  /// Canopy of the notes that carry no tag at all.
  static const String untaggedLabel = 'Sans parcelle';

  /// Tag shared by the members, or [untaggedLabel].
  final String label;

  /// Indices of the member nodes, in node-list order.
  final List<int> memberIndices;

  int get count => memberIndices.length;

  /// Canopy caption, e.g. « philosophie · 12 ».
  String get displayLabel => '$label · $count';

  /// Disc radius in graph space, growing with the member count and clamped
  /// so huge parcels do not swallow the whole canvas.
  double get radius => radiusFor(count);

  static const double _baseRadius = 24.0;
  static const double _radiusPerNote = 3.0;
  static const double _maxRadius = 140.0;

  /// See [radius].
  static double radiusFor(int count) =>
      (_baseRadius + _radiusPerNote * count).clamp(_baseRadius, _maxRadius);

  /// Groups nodes by dominant tag. [tagsByNode] holds the tags of each node,
  /// indexed like the graph node list.
  ///
  /// A node's dominant tag is the one of its tags that is the most frequent
  /// across the whole graph (alphabetical tie-break, deterministic). Nodes
  /// without tags fall into the [untaggedLabel] canopy. Canopies are sorted
  /// by descending member count, then by label.
  static List<GraphCanopy> build(List<List<String>> tagsByNode) {
    final frequency = <String, int>{};
    for (final tags in tagsByNode) {
      for (final tag in tags) {
        frequency[tag] = (frequency[tag] ?? 0) + 1;
      }
    }
    final members = <String, List<int>>{};
    for (var i = 0; i < tagsByNode.length; i++) {
      final tags = tagsByNode[i];
      final label = tags.isEmpty
          ? untaggedLabel
          : tags.reduce((a, b) {
              final byFrequency = frequency[a]! - frequency[b]!;
              if (byFrequency != 0) return byFrequency > 0 ? a : b;
              return a.compareTo(b) <= 0 ? a : b;
            });
      members.putIfAbsent(label, () => <int>[]).add(i);
    }
    final canopies = [
      for (final entry in members.entries)
        GraphCanopy(label: entry.key, memberIndices: entry.value),
    ];
    canopies.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.label.compareTo(b.label);
    });
    return canopies;
  }

  /// Centroid of the members' current positions, in graph space.
  static Offset centroidOf(List<int> memberIndices, List<GraphNode> nodes) {
    if (memberIndices.isEmpty) return Offset.zero;
    var sumX = 0.0, sumY = 0.0;
    for (final index in memberIndices) {
      sumX += nodes[index].x;
      sumY += nodes[index].y;
    }
    return Offset(sumX / memberIndices.length, sumY / memberIndices.length);
  }

  @override
  List<Object?> get props => [label, memberIndices];
}
