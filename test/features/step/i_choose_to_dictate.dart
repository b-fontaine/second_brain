import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I choose to dictate
///
/// Taps the « Dicter » chip of the seed dial. The chip closes the dial and
/// pushes the full-screen capture flow primed with the dictation event, so
/// the (fake) microphone starts immediately and the live transcript screen
/// is displayed — no intermediate mode-selection screen anymore.
Future<void> iChooseToDictate(WidgetTester tester) async {
  final chip = find.byKey(const Key('seed-dial-dictate'));
  expect(
    chip,
    findsOneWidget,
    reason: 'The seed dial should offer the « Dicter » entry',
  );
  await tester.tap(chip);
  await tester.pumpAndSettle();
  expect(
    find.text('Dictée en cours…'),
    findsOneWidget,
    reason: 'The live dictation screen should be displayed',
  );
}
