import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/serre_tokens.dart';
// Cross-feature imports — documented exception: the Explorer sheet reads
// the graph feature's loaded state (selection, counters) and the zettel
// feature's list bloc.
import '../../../graph/presentation/bloc/graph_state.dart';
import '../../../zettel/presentation/bloc/notes_list/notes_list_bloc.dart';
import 'explorer_note_groups.dart';

/// Persistent bottom sheet of the compact Explorer surface.
///
/// Three positions: [peekSize] shows the grab handle plus either the note
/// counter (cluster state) or the selection summary (title, links, close
/// notes, plots, « Ouvrir »); [selectionSize] gives the summary breathing
/// room; dragged towards [maxSize] it reveals the grouped chronological
/// notes list (list state).
class ExplorerSheet extends StatelessWidget {
  const ExplorerSheet({
    super.key,
    required this.controller,
    required this.graphState,
    required this.degreeById,
    required this.onOpenNote,
  });

  /// Collapsed peek: grab handle plus one summary line.
  static const double peekSize = 0.10;

  /// Raised enough to read the whole selection summary card.
  static const double selectionSize = 0.34;

  /// Near full-screen: the chronological list state.
  static const double maxSize = 0.90;

  final DraggableScrollableController controller;

  /// Loaded graph plus interaction state (selection, counters).
  final GraphLoaded graphState;

  /// Undirected link count per note id, for the maturity dots.
  final Map<String, int> degreeById;

  /// Called with a note id when a row or the « Ouvrir » button is tapped.
  final ValueChanged<String> onOpenNote;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SerreTokens>()!;
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: peekSize,
      minChildSize: peekSize,
      maxChildSize: maxSize,
      snap: true,
      snapSizes: const [selectionSize],
      builder: (context, scrollController) {
        return Container(
          key: const Key('explorer-sheet'),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: tokens.line)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, -4),
              ),
            ],
          ),
          // The list tiles paint their ink on the nearest Material
          // ancestor: keep one above the decorated background, otherwise
          // splashes would be hidden (and the framework asserts in tests).
          child: Material(
            type: MaterialType.transparency,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: BlocBuilder<NotesListBloc, NotesListState>(
              builder: (context, notesState) {
                // A single scrollable bound to the sheet controller: dragging
                // anywhere (handle included) raises or lowers the sheet.
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    const _SheetHandle(),
                    _SheetHeader(
                      graphState: graphState,
                      onOpenNote: onOpenNote,
                    ),
                    const Divider(height: 16),
                    ..._noteChildren(context, notesState),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<Widget> _noteChildren(BuildContext context, NotesListState state) {
    return switch (state) {
      NotesListInitial() || NotesListLoading() => const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      NotesListError(:final message) => [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ],
      NotesListLoaded(:final zettels) => zettelGroupWidgets(
        context: context,
        zettels: zettels,
        degreeById: degreeById,
        onOpen: onOpenNote,
      ),
    };
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const Key('explorer-sheet-handle'),
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Peek header: the note counter, or the selection summary when a node is
/// selected.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.graphState, required this.onOpenNote});

  final GraphLoaded graphState;
  final ValueChanged<String> onOpenNote;

  @override
  Widget build(BuildContext context) {
    if (graphState.selectedId != null) {
      return ExplorerSelectionSummary(state: graphState, onOpen: onOpenNote);
    }
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    final count = graphState.noteCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        '$count note${count > 1 ? 's' : ''}',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(color: tokens.sub),
      ),
    );
  }
}

/// Summary of the selected node: title, link and close-note counts, plot
/// (tag) chips and the « Ouvrir » action. Used as the sheet peek content.
class ExplorerSelectionSummary extends StatelessWidget {
  const ExplorerSelectionSummary({
    super.key,
    required this.state,
    required this.onOpen,
  });

  final GraphLoaded state;

  /// Called with the selected note id when « Ouvrir » is tapped.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    final id = state.selectedId;
    if (id == null) return const SizedBox.shrink();
    GraphNodeInput? node;
    for (final candidate in state.nodes) {
      if (candidate.id == id) {
        node = candidate;
        break;
      }
    }
    if (node == null) return const SizedBox.shrink();
    final links = state.selectedNeighborIds.length;
    final blooms = state.suggestedIds.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            node.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '$links lien${links > 1 ? 's' : ''}'
            ' · $blooms proche${blooms > 1 ? 's' : ''}',
            style: theme.textTheme.labelSmall?.copyWith(color: tokens.sub),
          ),
          if (node.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final tag in node.tags)
                    Chip(
                      label: Text(tag, style: theme.textTheme.labelSmall),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const Key('explorer-open-note'),
              onPressed: () => onOpen(id),
              child: const Text('Ouvrir'),
            ),
          ),
        ],
      ),
    );
  }
}
