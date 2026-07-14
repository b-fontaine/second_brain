import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the transcript contains {'ceci est une note dictée'}
///
/// After stopping the dictation, the review screen shows the transcript
/// (« Dictée » badge) and its editable field contains the dictated words.
Future<void> theTranscriptContains(WidgetTester tester, String param1) async {
  expect(
    find.widgetWithText(Chip, 'Dictée'),
    findsOneWidget,
    reason: 'The capture source badge should say « Dictée »',
  );
  final field = tester.widget<TextField>(find.byType(TextField));
  expect(
    field.controller?.text,
    contains(param1),
    reason: 'The reviewed transcript should contain the dictated words',
  );
}
