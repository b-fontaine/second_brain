import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the empty zettelkasten home screen
///
/// After onboarding, the setup page offers the optional AI-model download
/// step; skip it ("Plus tard") when shown, then assert the home screen
/// with its empty state.
Future<void> iSeeTheEmptyZettelkastenHomeScreen(WidgetTester tester) async {
  final skipModelStep = find.text('Plus tard');
  if (skipModelStep.evaluate().isNotEmpty) {
    await tester.tap(skipModelStep);
    await tester.pumpAndSettle();
  }
  expect(find.byKey(const Key('notes-search-bar')), findsOneWidget);
  expect(find.byKey(const Key('new-note-fab')), findsOneWidget);
  expect(find.text("Aucune note pour l'instant…"), findsOneWidget);
}
