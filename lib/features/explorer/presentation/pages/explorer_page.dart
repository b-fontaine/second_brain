import 'package:flutter/material.dart';

import '../../../zettel/presentation/widgets/notes_browser.dart';

/// Explorer surface (route `/`): the right-hand shell tab.
///
/// Jalon A: simply hosts the shared [NotesBrowser] (searchable list plus
/// reading panel). Chantier 2 merges the graph constellation into this
/// page (single surface, five states) and removes NotesHomePage/GraphPage.
class ExplorerPage extends StatelessWidget {
  const ExplorerPage({super.key});

  @override
  Widget build(BuildContext context) => const NotesBrowser();
}
