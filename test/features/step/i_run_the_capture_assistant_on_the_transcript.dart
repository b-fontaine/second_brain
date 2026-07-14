import 'package:flutter_test/flutter_test.dart';

/// Usage: I run the capture assistant on the transcript
///
/// From the transcript review screen, hands the text to the assistant.
Future<void> iRunTheCaptureAssistantOnTheTranscript(WidgetTester tester) async {
  final organize = find.text('Organiser avec l’assistant');
  expect(
    organize,
    findsOneWidget,
    reason: 'A transcript should be up for review',
  );
  await tester.tap(organize);
  await tester.pumpAndSettle();
}
