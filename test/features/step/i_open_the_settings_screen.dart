import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the settings screen
///
/// Taps the AppBar settings button (tooltip 'Réglages'), which pushes the
/// `/settings` route, and waits for the screen to load.
Future<void> iOpenTheSettingsScreen(WidgetTester tester) async {
  final settingsButton = find.byTooltip('Réglages');
  expect(
    settingsButton,
    findsOneWidget,
    reason: 'The AppBar settings button should be visible',
  );
  await tester.tap(settingsButton);
  await tester.pumpAndSettle();
  expect(
    find.text('Paramètres'),
    findsOneWidget,
    reason: 'The settings screen should be displayed',
  );
}
