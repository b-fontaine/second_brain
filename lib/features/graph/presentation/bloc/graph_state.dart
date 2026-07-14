import 'package:equatable/equatable.dart';

/// Node input of the graph: one zettel.
class GraphNodeInput extends Equatable {
  const GraphNodeInput({required this.id, required this.title});

  final String id;
  final String title;

  @override
  List<Object?> get props => [id, title];
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
  });

  final List<GraphNodeInput> nodes;
  final List<GraphLinkInput> edges;

  /// Monotonically increasing; bumped on every rebuild triggered by a vault
  /// change so the view knows to rebuild its simulation and reheat.
  final int revision;

  int get noteCount => nodes.length;

  int get linkCount => edges.length;

  @override
  List<Object?> get props => [nodes, edges, revision];
}
