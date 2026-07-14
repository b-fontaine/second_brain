import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the recognized text is shown for review
///
/// Review screen: « Capture d’écran » source badge and editable field
/// pre-filled with the OCR output.
Future<void> theRecognizedTextIsShownForReview(WidgetTester tester) async {
  expect(
    fakeOcrService.recognizedImages,
    isNotEmpty,
    reason: 'The OCR engine should have received the image',
  );
  expect(
    find.widgetWithText(Chip, 'Capture d’écran'),
    findsOneWidget,
    reason: 'The capture source badge should say « Capture d’écran »',
  );
  final field = tester.widget<TextField>(find.byType(TextField));
  expect(
    field.controller?.text,
    fakeOcrService.scriptedText,
    reason: 'The review field should be pre-filled with the recognized text',
  );
}
