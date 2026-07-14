import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the clipboard content is shown as capture source
///
/// The extracted-text review screen must display the « Presse-papiers »
/// source badge and its editable field must hold the clipboard text.
Future<void> theClipboardContentIsShownAsCaptureSource(
  WidgetTester tester,
) async {
  expect(
    find.widgetWithText(Chip, 'Presse-papiers'),
    findsOneWidget,
    reason: 'The capture source badge should say « Presse-papiers »',
  );
  final field = tester.widget<TextField>(find.byType(TextField));
  expect(
    field.controller?.text,
    fakeClipboardService.content.text,
    reason: 'The review field should be pre-filled with the clipboard text',
  );
}
