import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/presentation/bloc/notes_list/notes_list_bloc.dart';

/// Usage: I search for {'Concept A'} in the note list
Future<void> iSearchForInTheNoteList(WidgetTester tester, String param1) async {
  await tester.enterText(find.byKey(const Key('notes-search-bar')), param1);
  // The list bloc debounces keystrokes before searching.
  await tester.pump(
    NotesListBloc.searchDebounce + const Duration(milliseconds: 50),
  );
  await tester.pumpAndSettle();
}
