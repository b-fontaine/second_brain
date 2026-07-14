import 'package:flutter_test/flutter_test.dart';

import 'i_tap_the_capture_button.dart';

/// Usage: I run the capture assistant on the clipboard content
///
/// Full user journey: open the Capturer tab, import the clipboard content,
/// then hand the extracted text over to the assistant.
Future<void> iRunTheCaptureAssistantOnTheClipboardContent(
  WidgetTester tester,
) async {
  await iTapTheCaptureButton(tester);

  final card = find.text('Presse-papiers');
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();

  final organize = find.text('Organiser avec l’assistant');
  expect(
    organize,
    findsOneWidget,
    reason: 'The extracted clipboard text should be up for review',
  );
  await tester.tap(organize);
  await tester.pumpAndSettle();
}
