import 'package:flutter/material.dart';

import '../widgets/notes_browser.dart';

/// Former home screen: since the « 2 + 1 » navigation (jalon A) the route
/// `/` shows the Explorer surface, which hosts the same [NotesBrowser].
/// Kept until chantier 2 merges list and graph and removes this page.
class NotesHomePage extends StatelessWidget {
  const NotesHomePage({super.key});

  @override
  Widget build(BuildContext context) => const NotesBrowser();
}
