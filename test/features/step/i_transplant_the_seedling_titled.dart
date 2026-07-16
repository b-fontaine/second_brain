import 'package:flutter_test/flutter_test.dart';

import 'nursery_card_finder.dart';

/// Usage: I transplant the seedling titled {'Paillage du potager en été'}
///
/// Taps « Repiquer » on the nursery card carrying this title: the capture
/// becomes a permanent zettel and leaves the pending queue.
Future<void> iTransplantTheSeedlingTitled(
  WidgetTester tester,
  String param1,
) async {
  final transplant = find.descendant(
    of: findNurseryCardTitled(param1),
    matching: find.text('Repiquer'),
  );
  expect(
    transplant,
    findsOneWidget,
    reason: 'The card « $param1 » should offer the « Repiquer » action',
  );
  await tester.ensureVisible(transplant);
  await tester.pumpAndSettle();
  await tester.tap(transplant);
  await tester.pumpAndSettle();
}
