import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I enter {'Une idée atomique par note.'} as the note body
Future<void> iEnterAsTheNoteBody(WidgetTester tester, String param1) async {
  await tester.enterText(find.byKey(const Key('note-body-field')), param1);
  await tester.pump();
}
