import 'package:flutter_test/flutter_test.dart';

/// Usage: I run the capture assistant on the OCR text
///
/// From the recognized-text review screen, hands the text to the assistant.
Future<void> iRunTheCaptureAssistantOnTheOcrText(WidgetTester tester) async {
  final organize = find.text('Organiser avec l’assistant');
  expect(
    organize,
    findsOneWidget,
    reason: 'An OCR result should be up for review',
  );
  await tester.tap(organize);
  await tester.pumpAndSettle();
}
