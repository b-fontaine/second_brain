import 'package:flutter_test/flutter_test.dart';

/// Usage: I start dictating
///
/// Taps the « Dictée » source card, which starts the (fake) microphone
/// dictation and shows the live transcript screen.
Future<void> iStartDictating(WidgetTester tester) async {
  final card = find.text('Dictée');
  expect(card, findsOneWidget);
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
  expect(
    find.text('Dictée en cours…'),
    findsOneWidget,
    reason: 'The live dictation screen should be displayed',
  );
}
