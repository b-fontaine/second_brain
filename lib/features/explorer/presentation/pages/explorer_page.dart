import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
// Cross-feature imports — documented exception: the Explorer surface is the
// fusion of the notes list and the graph constellation (chantier 2 of the
// « La Serre » plan); it composes the blocs and widgets those features
// expose.
import '../../../graph/presentation/bloc/graph_cubit.dart';
import '../../../graph/presentation/bloc/graph_state.dart';
import '../../../graph/presentation/widgets/graph_reading_panel.dart';
import '../../../zettel/domain/entities/zettel_id.dart';
import '../../../zettel/presentation/bloc/notes_list/notes_list_bloc.dart';
import '../bloc/seedling_count_cubit.dart';
import '../widgets/explorer_constellation.dart';
import '../widgets/explorer_empty_view.dart';
import '../widgets/explorer_note_groups.dart';
import '../widgets/explorer_pills.dart';
import '../widgets/explorer_search_bar.dart';
import '../widgets/explorer_search_results.dart';
import '../widgets/explorer_sheet.dart';

/// Explorer surface (route `/`): the fused « jardin » — one surface, five
/// states.
///
/// - **vide** : sprout illustration guiding towards the « Semer » button ;
/// - **amas** : full-screen constellation, sheet collapsed to its peek
///   (handle + note counter) ;
/// - **sélection** : coral ring on the tapped node, sheet peek showing the
///   summary (title, links, close notes, plots, « Ouvrir ») — expanded
///   layouts open a right-hand reading panel instead ;
/// - **recherche** : floating results under the search bar while the
///   matched nodes stay lit and the rest of the constellation dims ;
/// - **liste** : sheet dragged up, grouped chronological list (expanded
///   layouts toggle a left panel from the pills row).
class ExplorerPage extends StatelessWidget {
  const ExplorerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<GraphCubit>()..load()),
        BlocProvider(
          create: (_) => getIt<NotesListBloc>()..add(const NotesListStarted()),
        ),
        BlocProvider(create: (_) => getIt<SeedlingCountCubit>()..start()),
      ],
      child: const _ExplorerView(),
    );
  }
}

class _ExplorerView extends StatefulWidget {
  const _ExplorerView();

  @override
  State<_ExplorerView> createState() => _ExplorerViewState();
}

class _ExplorerViewState extends State<_ExplorerView> {
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  /// Expanded layouts: whether the left notes panel is shown.
  bool _notesPanelOpen = false;

  int _degreesRevision = -1;
  Map<String, int> _degreeById = const {};

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  /// Undirected degree (outgoing links plus backlinks) per note id,
  /// memoized per graph revision — drives the maturity dots of every list.
  Map<String, int> _degreesFor(GraphState state) {
    if (state is! GraphLoaded) return const {};
    if (state.revision != _degreesRevision) {
      final degrees = <String, int>{for (final node in state.nodes) node.id: 0};
      for (final edge in state.edges) {
        final source = state.nodes[edge.source].id;
        final target = state.nodes[edge.target].id;
        degrees[source] = degrees[source]! + 1;
        degrees[target] = degrees[target]! + 1;
      }
      _degreesRevision = state.revision;
      _degreeById = degrees;
    }
    return _degreeById;
  }

  void _openNote(String id) => context.push(AppRoutes.noteDetail(id));

  /// Search mode: keeps the matched nodes lit on the constellation; an
  /// empty query restores the normal display.
  void _syncSearchHighlight(BuildContext context, NotesListState state) {
    if (state is! NotesListLoaded) return;
    context.read<GraphCubit>().setHighlighted(
      state.query.trim().isEmpty
          ? const {}
          : {for (final zettel in state.zettels) zettel.id.value},
    );
  }

  /// Compact layouts: lifts the sheet to the summary position when a node
  /// is selected and lowers it back to the peek when the selection clears —
  /// without ever fighting a sheet the user raised to the list state.
  void _reactToSelection(BuildContext context, GraphState state) {
    if (state is! GraphLoaded) return;
    if (Breakpoints.isExpanded(context)) return;
    if (!_sheetController.isAttached) return;
    const duration = Duration(milliseconds: 250);
    const curve = Curves.easeOutCubic;
    final size = _sheetController.size;
    if (state.selectedId != null) {
      if (size < ExplorerSheet.selectionSize) {
        _sheetController.animateTo(
          ExplorerSheet.selectionSize,
          duration: duration,
          curve: curve,
        );
      }
    } else if (size <= ExplorerSheet.selectionSize) {
      _sheetController.animateTo(
        ExplorerSheet.peekSize,
        duration: duration,
        curve: curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = Breakpoints.isExpanded(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<NotesListBloc, NotesListState>(
          listener: _syncSearchHighlight,
        ),
        BlocListener<GraphCubit, GraphState>(
          listenWhen: (previous, current) {
            final previousId = previous is GraphLoaded
                ? previous.selectedId
                : null;
            final currentId = current is GraphLoaded
                ? current.selectedId
                : null;
            return previousId != currentId;
          },
          listener: _reactToSelection,
        ),
      ],
      child: Scaffold(
        body: SafeArea(
          child: expanded ? _buildExpanded(context) : _buildCompact(context),
        ),
        floatingActionButton: Padding(
          // Clears the shell « Semer » FAB floating at the same corner on
          // expanded layouts, and the sheet peek on compact ones.
          padding: EdgeInsets.only(bottom: expanded ? 76 : 84),
          child: FloatingActionButton(
            key: const Key('new-note-fab'),
            tooltip: 'Nouvelle note',
            onPressed: () => context.push(AppRoutes.newNote),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return BlocBuilder<GraphCubit, GraphState>(
      builder: (context, state) {
        final degreeById = _degreesFor(state);
        return Stack(
          children: [
            Positioned.fill(child: _buildCanvasArea(context, state)),
            if (state is GraphLoaded && !state.isEmpty)
              ExplorerSheet(
                controller: _sheetController,
                graphState: state,
                degreeById: degreeById,
                onOpenNote: _openNote,
              ),
            // Last: the search bar and its results stay reachable above a
            // raised sheet.
            _buildTopOverlay(context, degreeById: degreeById, expanded: false),
          ],
        );
      },
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return BlocBuilder<GraphCubit, GraphState>(
      builder: (context, state) {
        final degreeById = _degreesFor(state);
        final selectedId = state is GraphLoaded ? state.selectedId : null;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_notesPanelOpen) ...[
              SizedBox(
                width: 360,
                child: ExplorerNotesPanel(
                  degreeById: degreeById,
                  // Desktop: opening a note from the list means reading it
                  // in the side panel (mirrors a node selection).
                  onOpen: (id) => context.read<GraphCubit>().selectNode(id),
                ),
              ),
              const VerticalDivider(width: 1),
            ],
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildCanvasArea(context, state)),
                  _buildTopOverlay(
                    context,
                    degreeById: degreeById,
                    expanded: true,
                  ),
                ],
              ),
            ),
            if (selectedId != null) ...[
              const VerticalDivider(width: 1),
              SizedBox(
                width: 400,
                child: GraphReadingPanel(
                  key: ValueKey(selectedId),
                  zettelId: ZettelId.fromString(selectedId),
                  onClose: () => context.read<GraphCubit>().selectNode(null),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Constellation, or the state that replaces it (loading, failure,
  /// empty garden).
  Widget _buildCanvasArea(BuildContext context, GraphState state) {
    return switch (state) {
      GraphInitial() ||
      GraphLoading() => const Center(child: CircularProgressIndicator()),
      GraphLoadFailure(:final message) => _GraphErrorView(message: message),
      GraphLoaded() =>
        state.isEmpty
            ? const ExplorerEmptyView()
            : ExplorerConstellation(state: state),
    };
  }

  /// Floating column pinned to the top of the canvas: search bar, status
  /// pills, and the search results while a query is active. Empty regions
  /// let taps fall through to the constellation.
  Widget _buildTopOverlay(
    BuildContext context, {
    required Map<String, int> degreeById,
    required bool expanded,
  }) {
    return Positioned(
      top: 8,
      left: 12,
      right: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExplorerSearchBar(
            controller: _searchController,
            showSettingsButton: !expanded,
            onChanged: (query) =>
                context.read<NotesListBloc>().add(NotesListQueryChanged(query)),
          ),
          const SizedBox(height: 8),
          ExplorerPills(
            onToggleNotesList: expanded
                ? () => setState(() => _notesPanelOpen = !_notesPanelOpen)
                : null,
          ),
          const SizedBox(height: 8),
          ExplorerSearchResults(
            degreeById: degreeById,
            onOpen: (id) {
              if (expanded) {
                context.read<GraphCubit>().selectNode(id);
              } else {
                _openNote(id);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _GraphErrorView extends StatelessWidget {
  const _GraphErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
      ),
    );
  }
}
