import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the nursery from the explorer pill
///
/// Taps the « n semis » pill of the Explorer surface, which pushes the
/// « Pépinière — brouillons à valider » review above the shell.
Future<void> iOpenTheNurseryFromTheExplorerPill(WidgetTester tester) async {
  // Let the seedling-count cubit process the latest vault-write pulse.
  await tester.pumpAndSettle();
  final pill = find.byKey(const Key('explorer-seedling-pill'));
  expect(
    pill,
    findsOneWidget,
    reason:
        'The « n semis » pill should be visible on the Explorer '
        '(at least one pending capture)',
  );
  await tester.tap(pill);
  await tester.pumpAndSettle();
  expect(
    find.text('Pépinière'),
    findsOneWidget,
    reason: 'The nursery review screen should be displayed',
  );
}
