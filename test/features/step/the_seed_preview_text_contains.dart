import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the seed preview text contains {'notes atomiques'}
///
/// The editable « Texte extrait » field of the sowing preview holds the
/// extracted text (clipboard content, transcript or OCR output).
Future<void> theSeedPreviewTextContains(
  WidgetTester tester,
  String param1,
) async {
  final fieldFinder = find.byKey(const Key('seed-preview-text'));
  expect(
    fieldFinder,
    findsOneWidget,
    reason: 'The sowing preview should display its extracted-text field',
  );
  final field = tester.widget<TextField>(fieldFinder);
  expect(
    field.controller?.text,
    contains(param1),
    reason: 'The extracted text should contain « $param1 »',
  );
}
