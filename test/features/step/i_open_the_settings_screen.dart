import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the settings screen
///
/// Taps the settings gear (tooltip 'Réglages') — hosted by the Explorer
/// search bar on the compact test surface (bottom of the navigation rail on
/// expanded layouts) — which pushes the `/settings` route, and waits for
/// the screen to load.
Future<void> iOpenTheSettingsScreen(WidgetTester tester) async {
  final settingsButton = find.byTooltip('Réglages');
  expect(
    settingsButton,
    findsOneWidget,
    reason: 'The settings gear should be visible',
  );
  await tester.tap(settingsButton);
  await tester.pumpAndSettle();
  expect(
    find.text('Paramètres'),
    findsOneWidget,
    reason: 'The settings screen should be displayed',
  );
}
