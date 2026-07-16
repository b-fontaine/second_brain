import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the explorer seedling pill is hidden
///
/// With zero pending capture, the Explorer surface hides the « n semis »
/// pill entirely.
Future<void> theExplorerSeedlingPillIsHidden(WidgetTester tester) async {
  // Let the seedling-count cubit process the latest vault-write pulse.
  await tester.pumpAndSettle();
  expect(
    find.byKey(const Key('explorer-seedling-pill')),
    findsNothing,
    reason: 'The « n semis » pill should be hidden when the nursery is empty',
  );
}
