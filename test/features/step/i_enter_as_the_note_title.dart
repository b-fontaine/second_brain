import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I enter {'Ma première idée'} as the note title
Future<void> iEnterAsTheNoteTitle(WidgetTester tester, String param1) async {
  await tester.enterText(find.byKey(const Key('note-title-field')), param1);
  await tester.pump();
}
