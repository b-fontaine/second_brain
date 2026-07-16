import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nursery_card_finder.dart';

/// Usage: I compost the seedling titled {'Taille des rosiers anciens'}
///
/// Taps « Composter » on the nursery card carrying this title, then
/// confirms the light dialog: the draft is removed for good.
Future<void> iCompostTheSeedlingTitled(
  WidgetTester tester,
  String param1,
) async {
  final compost = find.descendant(
    of: findNurseryCardTitled(param1),
    matching: find.text('Composter'),
  );
  expect(
    compost,
    findsOneWidget,
    reason: 'The card « $param1 » should offer the « Composter » action',
  );
  await tester.ensureVisible(compost);
  await tester.pumpAndSettle();
  await tester.tap(compost);
  await tester.pumpAndSettle();

  final confirm = find.byKey(const Key('pepiniere-compost-confirm'));
  expect(
    confirm,
    findsOneWidget,
    reason: 'A confirmation dialog should be shown before composting',
  );
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}
