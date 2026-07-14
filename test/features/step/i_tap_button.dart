import 'package:flutter_test/flutter_test.dart';

/// Usage: I tap {'Continuer sans synchronisation'} button
///
/// Taps the (unique) widget displaying exactly this label — buttons render
/// their label as a Text child, so tapping the label taps the button.
Future<void> iTapButton(WidgetTester tester, String param1) async {
  final label = find.text(param1);
  expect(
    label,
    findsOneWidget,
    reason: "A button labelled '$param1' should be visible",
  );
  // The onboarding form scrolls on small surfaces: bring the button
  // on-screen before tapping (a tap outside the viewport is a no-op).
  await tester.ensureVisible(label);
  await tester.pumpAndSettle();
  await tester.tap(label);
  await tester.pumpAndSettle();
}
