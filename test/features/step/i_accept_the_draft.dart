import 'package:flutter_test/flutter_test.dart';

/// Usage: I accept the draft
///
/// Taps the « Accepter » button of the (single) proposed draft card.
/// `find.text` matches exactly, so the neighbouring « Tout accepter »
/// button is not ambiguous.
Future<void> iAcceptTheDraft(WidgetTester tester) async {
  final accept = find.text('Accepter');
  expect(
    accept,
    findsOneWidget,
    reason: 'Exactly one draft should be up for acceptance',
  );
  await tester.ensureVisible(accept);
  await tester.pumpAndSettle();
  await tester.tap(accept);
  await tester.pumpAndSettle();
}
