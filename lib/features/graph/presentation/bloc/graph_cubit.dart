import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../zettel/domain/entities/zettel.dart';
import '../../../zettel/domain/repositories/zettel_repository.dart';
import '../../../zettel/domain/usecases/get_all_zettels.dart';
import '../../domain/usecases/suggest_related_notes.dart';
import '../../domain/usecases/watch_vault.dart';
import '../utils/graph_canopy.dart';
import '../utils/graph_lod.dart';
import 'graph_state.dart';

/// Loads the vault as a graph (zettels = nodes, wikilinks = edges) and
/// rebuilds it whenever the vault changes. Also carries the interaction
/// state consumed by the Explorer surface: selection (with its linked and
/// suggested neighborhoods), search highlighting and the current level of
/// detail reported by the view.
@injectable
class GraphCubit extends Cubit<GraphState> {
  GraphCubit(this._getAllZettels, this._watchVault, this._suggestRelatedNotes)
    : super(const GraphInitial());

  final GetAllZettels _getAllZettels;
  final WatchVault _watchVault;
  final SuggestRelatedNotes _suggestRelatedNotes;

  StreamSubscription<Either<Failure, VaultChanged>>? _vaultSubscription;
  int _revision = 0;

  /// How many non-linked related notes are flagged as « fleurs » around a
  /// selected node.
  static const int _suggestionCount = 5;

  Future<void> load() async {
    emit(const GraphLoading());
    final result = await _getAllZettels(const NoParams());
    if (isClosed) return;
    result.fold(
      (failure) => emit(GraphLoadFailure(failure.message)),
      (zettels) => emit(_mapToLoaded(zettels)),
    );
    _vaultSubscription ??= _watchVault(
      const NoParams(),
    ).listen((_) => _refresh());
  }

  /// Selects [id] (or clears the selection when null), exposing its 1-hop
  /// neighbors, then asks the local AI for close-but-unlinked notes and
  /// flags them as « fleurs ». Stale answers (selection moved on before the
  /// index replied) are dropped.
  Future<void> selectNode(String? id) async {
    final loaded = state;
    if (loaded is! GraphLoaded) return;
    if (id == null) {
      emit(
        loaded.copyWith(
          selectedId: null,
          selectedNeighborIds: const {},
          suggestedIds: const {},
        ),
      );
      return;
    }
    final neighbors = _neighborIdsOf(loaded, id);
    emit(
      loaded.copyWith(
        selectedId: id,
        selectedNeighborIds: neighbors,
        suggestedIds: const {},
      ),
    );
    final result = await _suggestRelatedNotes(
      SuggestRelatedNotesParams(
        zettelId: id,
        excludedIds: {id, ...neighbors},
        count: _suggestionCount,
      ),
    );
    if (isClosed) return;
    final current = state;
    if (current is! GraphLoaded || current.selectedId != id) return;
    result.fold((_) {}, (ids) {
      final live = {for (final node in current.nodes) node.id};
      emit(
        current.copyWith(
          suggestedIds: {
            for (final suggested in ids)
              if (live.contains(suggested)) suggested,
          },
        ),
      );
    });
  }

  /// Search mode: keeps [ids] lit while the rest of the constellation is
  /// dimmed. An empty set restores the normal display.
  void setHighlighted(Set<String> ids) {
    final loaded = state;
    if (loaded is! GraphLoaded) return;
    emit(loaded.copyWith(highlightedIds: Set.of(ids)));
  }

  /// Notified by the view whenever the viewport scale changes; only emits
  /// when the derived level of detail actually crosses a threshold.
  void viewScaleChanged(double scale) {
    final loaded = state;
    if (loaded is! GraphLoaded) return;
    final lod = GraphLod.forScale(scale);
    if (lod != loaded.lod) emit(loaded.copyWith(lod: lod));
  }

  /// Silent refresh after a vault change: keeps the last good graph on
  /// failure (offline-first, never break the view for a transient error).
  Future<void> _refresh() async {
    final result = await _getAllZettels(const NoParams());
    if (isClosed) return;
    result.fold((_) {}, (zettels) => emit(_mapToLoaded(zettels)));
  }

  /// Maps zettels to nodes and undirected edges. Wikilinks pointing to ids
  /// absent from the vault, self-links and duplicate/reciprocal links are
  /// ignored. The interaction state (selection, search, suggestions, LOD)
  /// is carried over, dropping ids that left the vault.
  GraphLoaded _mapToLoaded(List<Zettel> zettels) {
    final nodes = <GraphNodeInput>[];
    final indexById = <String, int>{};
    for (var i = 0; i < zettels.length; i++) {
      indexById[zettels[i].id.value] = i;
      nodes.add(
        GraphNodeInput(
          id: zettels[i].id.value,
          title: zettels[i].title,
          tags: zettels[i].tags,
        ),
      );
    }
    final edges = <GraphLinkInput>[];
    final seen = <int>{};
    for (var i = 0; i < zettels.length; i++) {
      for (final target in zettels[i].outgoingLinks) {
        final j = indexById[target.value];
        if (j == null || j == i) continue;
        final low = i < j ? i : j;
        final high = i < j ? j : i;
        if (seen.add(low * nodes.length + high)) {
          edges.add(GraphLinkInput(source: i, target: j));
        }
      }
    }
    final canopies = GraphCanopy.build([for (final z in zettels) z.tags]);
    final previous = state;
    String? selectedId;
    var highlightedIds = const <String>{};
    var suggestedIds = const <String>{};
    var lod = GraphLod.detail;
    if (previous is GraphLoaded) {
      lod = previous.lod;
      highlightedIds = {
        for (final id in previous.highlightedIds)
          if (indexById.containsKey(id)) id,
      };
      suggestedIds = {
        for (final id in previous.suggestedIds)
          if (indexById.containsKey(id)) id,
      };
      final kept = previous.selectedId;
      if (kept != null && indexById.containsKey(kept)) selectedId = kept;
    }
    final loaded = GraphLoaded(
      nodes: nodes,
      edges: edges,
      revision: _revision++,
      canopies: canopies,
      selectedId: selectedId,
      highlightedIds: highlightedIds,
      suggestedIds: suggestedIds,
      lod: lod,
    );
    if (selectedId == null) return loaded;
    return loaded.copyWith(
      selectedNeighborIds: _neighborIdsOf(loaded, selectedId),
    );
  }

  /// 1-hop neighbor ids of [id] (edges are undirected: outgoing links and
  /// backlinks alike).
  Set<String> _neighborIdsOf(GraphLoaded loaded, String id) {
    var index = -1;
    for (var i = 0; i < loaded.nodes.length; i++) {
      if (loaded.nodes[i].id == id) {
        index = i;
        break;
      }
    }
    if (index < 0) return const {};
    final neighbors = <String>{};
    for (final edge in loaded.edges) {
      if (edge.source == index) neighbors.add(loaded.nodes[edge.target].id);
      if (edge.target == index) neighbors.add(loaded.nodes[edge.source].id);
    }
    return neighbors;
  }

  @override
  Future<void> close() async {
    await _vaultSubscription?.cancel();
    return super.close();
  }
}
