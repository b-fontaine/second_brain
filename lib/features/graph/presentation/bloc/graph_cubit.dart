import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../zettel/domain/entities/zettel.dart';
import '../../../zettel/domain/repositories/zettel_repository.dart';
import '../../../zettel/domain/usecases/get_all_zettels.dart';
import '../../domain/usecases/watch_vault.dart';
import 'graph_state.dart';

/// Loads the vault as a graph (zettels = nodes, wikilinks = edges) and
/// rebuilds it whenever the vault changes.
@injectable
class GraphCubit extends Cubit<GraphState> {
  GraphCubit(this._getAllZettels, this._watchVault)
    : super(const GraphInitial());

  final GetAllZettels _getAllZettels;
  final WatchVault _watchVault;

  StreamSubscription<Either<Failure, VaultChanged>>? _vaultSubscription;
  int _revision = 0;

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

  /// Silent refresh after a vault change: keeps the last good graph on
  /// failure (offline-first, never break the view for a transient error).
  Future<void> _refresh() async {
    final result = await _getAllZettels(const NoParams());
    if (isClosed) return;
    result.fold((_) {}, (zettels) => emit(_mapToLoaded(zettels)));
  }

  /// Maps zettels to nodes and undirected edges. Wikilinks pointing to ids
  /// absent from the vault, self-links and duplicate/reciprocal links are
  /// ignored.
  GraphLoaded _mapToLoaded(List<Zettel> zettels) {
    final nodes = <GraphNodeInput>[];
    final indexById = <String, int>{};
    for (var i = 0; i < zettels.length; i++) {
      indexById[zettels[i].id.value] = i;
      nodes.add(
        GraphNodeInput(id: zettels[i].id.value, title: zettels[i].title),
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
    return GraphLoaded(nodes: nodes, edges: edges, revision: _revision++);
  }

  @override
  Future<void> close() async {
    await _vaultSubscription?.cancel();
    return super.close();
  }
}
