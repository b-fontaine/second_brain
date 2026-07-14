import 'package:flutter_test/flutter_test.dart';

/// Usage: I choose the dictation capture mode
///
/// Asserts the « Dictée » source card is offered. Tapping the card is what
/// actually starts the microphone — which is exactly the job of the next
/// step, "I start dictating" — so the choice itself only checks the card.
Future<void> iChooseTheDictationCaptureMode(WidgetTester tester) async {
  expect(
    find.text('Dictée'),
    findsOneWidget,
    reason: 'The dictation capture mode should be offered',
  );
}
