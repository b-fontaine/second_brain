import 'package:equatable/equatable.dart';

import '../utils/graph_canopy.dart';
import '../utils/graph_lod.dart';

/// Node input of the graph: one zettel.
class GraphNodeInput extends Equatable {
  const GraphNodeInput({
    required this.id,
    required this.title,
    this.tags = const [],
  });

  final String id;
  final String title;

  /// Tags of the zettel; drive the canopy grouping of the zoomed-out view.
  final List<String> tags;

  @override
  List<Object?> get props => [id, title, tags];
}

/// Undirected link between two nodes, as indices into [GraphLoaded.nodes].
class GraphLinkInput extends Equatable {
  const GraphLinkInput({required this.source, required this.target});

  final int source;
  final int target;

  @override
  List<Object?> get props => [source, target];
}

sealed class GraphState extends Equatable {
  const GraphState();

  @override
  List<Object?> get props => const [];
}

final class GraphInitial extends GraphState {
  const GraphInitial();
}

final class GraphLoading extends GraphState {
  const GraphLoading();
}

final class GraphLoadFailure extends GraphState {
  const GraphLoadFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class GraphLoaded extends GraphState {
  const GraphLoaded({
    required this.nodes,
    required this.edges,
    required this.revision,
    this.canopies = const [],
    this.selectedId,
    this.selectedNeighborIds = const {},
    this.highlightedIds = const {},
    this.suggestedIds = const {},
    this.lod = GraphLod.detail,
  });

  final List<GraphNodeInput> nodes;
  final List<GraphLinkInput> edges;

  /// Monotonically increasing; bumped on every rebuild triggered by a vault
  /// change so the view knows to rebuild its simulation and reheat.
  final int revision;

  /// Tag canopies of the zoomed-out view, precomputed once per revision.
  final List<GraphCanopy> canopies;

  /// Id of the selected note, or null when nothing is selected.
  final String? selectedId;

  /// Ids linked to [selectedId] (1-hop neighbors, both directions).
  final Set<String> selectedNeighborIds;

  /// Search mode: ids kept lit while everything else is dimmed.
  /// Empty means normal mode (nothing dimmed).
  final Set<String> highlightedIds;

  /// « Fleurs » : ids suggested by the local AI as close to the selection
  /// but not linked to it yet.
  final Set<String> suggestedIds;

  /// Current level of detail, derived from the view scale reported through
  /// [GraphCubit.viewScaleChanged].
  final GraphLod lod;

  int get noteCount => nodes.length;

  int get linkCount => edges.length;

  bool get isEmpty => nodes.isEmpty;

  static const Object _unset = Object();

  /// Copies the interaction state; the graph itself (nodes, edges, canopies,
  /// revision) is only ever rebuilt by the cubit from the vault.
  GraphLoaded copyWith({
    Object? selectedId = _unset,
    Set<String>? selectedNeighborIds,
    Set<String>? highlightedIds,
    Set<String>? suggestedIds,
    GraphLod? lod,
  }) {
    return GraphLoaded(
      nodes: nodes,
      edges: edges,
      revision: revision,
      canopies: canopies,
      selectedId: identical(selectedId, _unset)
          ? this.selectedId
          : selectedId as String?,
      selectedNeighborIds: selectedNeighborIds ?? this.selectedNeighborIds,
      highlightedIds: highlightedIds ?? this.highlightedIds,
      suggestedIds: suggestedIds ?? this.suggestedIds,
      lod: lod ?? this.lod,
    );
  }

  @override
  List<Object?> get props => [
    nodes,
    edges,
    revision,
    canopies,
    selectedId,
    selectedNeighborIds,
    highlightedIds,
    suggestedIds,
    lod,
  ];
}
