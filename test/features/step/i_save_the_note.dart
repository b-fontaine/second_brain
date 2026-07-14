import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I save the note
Future<void> iSaveTheNote(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('save-note-button')));
  await tester.pumpAndSettle();
}
