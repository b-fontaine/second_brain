import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/graph/presentation/pages/graph_page.dart';

/// Usage: I open the graph view
///
/// Taps the 'Graphe' destination of the adaptive shell (bottom
/// [NavigationBar] on the compact test surface). The force simulation is
/// driven by an open-ended Ticker, so `pumpAndSettle` is off-limits: pump a
/// bounded number of frames instead (cubit load → GraphLoaded, then a few
/// simulation ticks so the layout spreads out).
Future<void> iOpenTheGraphView(WidgetTester tester) async {
  final destination = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('Graphe'),
  );
  expect(
    destination,
    findsOneWidget,
    reason: "The shell navigation should offer a 'Graphe' destination",
  );
  await tester.tap(destination);
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    find.byType(GraphPage),
    findsOneWidget,
    reason: 'Tapping the Graphe destination should open the graph page',
  );
}
