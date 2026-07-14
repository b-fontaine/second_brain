import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I tap the new note button
Future<void> iTapTheNewNoteButton(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('new-note-fab')));
  await tester.pumpAndSettle();
}
