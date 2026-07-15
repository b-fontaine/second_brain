import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Cross-feature imports — documented exception: the Explorer lists reuse
// the zettel feature's entities, list bloc, tiles and maturity scale.
import '../../../zettel/domain/entities/zettel.dart';
import '../../../zettel/presentation/bloc/notes_list/notes_list_bloc.dart';
import '../../../zettel/presentation/utils/zettel_maturity.dart';
import '../../../zettel/presentation/utils/zettel_text_formats.dart';
import '../../../zettel/presentation/widgets/zettel_list_tile.dart';

/// Chronological list rows (newest first) grouped under French month-year
/// headers, each note badged with its maturity dot.
///
/// Returns plain children so callers can splice them into their own
/// scrollable (the Explorer sheet binds its ListView to the sheet
/// controller).
List<Widget> zettelGroupWidgets({
  required BuildContext context,
  required List<Zettel> zettels,
  required Map<String, int> degreeById,
  required ValueChanged<String> onOpen,
}) {
  final theme = Theme.of(context);
  if (zettels.isEmpty) {
    return [
      Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Aucune note à afficher.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];
  }
  final sorted = [...zettels]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final children = <Widget>[];
  String? group;
  for (final zettel in sorted) {
    final label = formatMonthYearFr(zettel.createdAt);
    if (label != group) {
      group = label;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    children.add(
      ZettelListTile(
        zettel: zettel,
        maturity: ZettelMaturity.of(degreeById[zettel.id.value] ?? 0),
        onTap: () => onOpen(zettel.id.value),
      ),
    );
  }
  return children;
}

/// Expanded layouts: left side panel hosting the grouped chronological
/// notes list (the compact counterpart lives in the bottom sheet).
class ExplorerNotesPanel extends StatelessWidget {
  const ExplorerNotesPanel({
    super.key,
    required this.degreeById,
    required this.onOpen,
  });

  /// Undirected link count per note id, for the maturity dots.
  final Map<String, int> degreeById;

  /// Called with the tapped note id.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesListBloc, NotesListState>(
      builder: (context, state) => switch (state) {
        NotesListInitial() ||
        NotesListLoading() => const Center(child: CircularProgressIndicator()),
        NotesListError(:final message) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
        NotesListLoaded(:final zettels) => ListView(
          key: const Key('explorer-notes-panel'),
          padding: const EdgeInsets.only(bottom: 24),
          children: zettelGroupWidgets(
            context: context,
            zettels: zettels,
            degreeById: degreeById,
            onOpen: onOpen,
          ),
        ),
      },
    );
  }
}
