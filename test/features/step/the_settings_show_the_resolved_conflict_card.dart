import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/sync/presentation/pages/settings_page.dart';

/// Usage: the settings show the resolved conflict card
///
/// The amber card (key `settings_conflict_card`) tops the settings column
/// whenever the last pull resolved conflicts local-wins, with the same
/// guidance as the shell toast.
Future<void> theSettingsShowTheResolvedConflictCard(
  WidgetTester tester,
) async {
  final card = find.byKey(const Key('settings_conflict_card'));
  expect(
    card,
    findsOneWidget,
    reason: 'The amber conflict card should be visible in the settings',
  );
  expect(
    find.descendant(
      of: card,
      matching: find.text('Conflit de synchronisation résolu'),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: card,
      matching: find.text(SettingsView.conflictCardMessage),
    ),
    findsOneWidget,
    reason: 'The card should explain the conflicts/ local-wins policy',
  );
}
