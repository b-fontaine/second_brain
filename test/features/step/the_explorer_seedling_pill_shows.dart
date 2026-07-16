import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the explorer seedling pill shows {'1 semis'}
///
/// The « n semis » pill of the Explorer surface displays this label
/// (pending-capture count fed by the vault-write pulses).
Future<void> theExplorerSeedlingPillShows(
  WidgetTester tester,
  String param1,
) async {
  // Let the seedling-count cubit process the latest vault-write pulse.
  await tester.pumpAndSettle();
  final pill = find.byKey(const Key('explorer-seedling-pill'));
  expect(
    pill,
    findsOneWidget,
    reason: 'The « n semis » pill should be visible on the Explorer',
  );
  expect(
    find.descendant(of: pill, matching: find.text(param1)),
    findsOneWidget,
    reason: 'The seedling pill should read « $param1 »',
  );
}
