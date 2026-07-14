import 'package:flutter_test/flutter_test.dart';

import 'i_choose_to_paste.dart';
import 'i_tap_the_seed_button.dart';

/// Usage: I run the capture assistant on the clipboard content
///
/// Full user journey: open the seed dial, paste the clipboard content
/// through the « Coller » chip, then hand the extracted text over to the
/// assistant.
Future<void> iRunTheCaptureAssistantOnTheClipboardContent(
  WidgetTester tester,
) async {
  await iTapTheSeedButton(tester);
  await iChooseToPaste(tester);

  final organize = find.text('Organiser avec l’assistant');
  expect(
    organize,
    findsOneWidget,
    reason: 'The extracted clipboard text should be up for review',
  );
  await tester.tap(organize);
  await tester.pumpAndSettle();
}
