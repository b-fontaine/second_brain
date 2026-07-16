import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/explorer/presentation/pages/explorer_page.dart';

/// Usage: I return to the explorer
///
/// Pops the nursery review (pushed above the shell) through its AppBar
/// back button, landing back on the Explorer surface.
Future<void> iReturnToTheExplorer(WidgetTester tester) async {
  final back = find.byType(BackButton);
  expect(
    back,
    findsOneWidget,
    reason: 'A screen pushed above the shell should carry a back button',
  );
  await tester.tap(back);
  await tester.pumpAndSettle();
  expect(
    find.byType(ExplorerPage),
    findsOneWidget,
    reason: 'The app should be back on the Explorer surface',
  );
}
