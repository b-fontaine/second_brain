import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the app is running with a configured vault
Future<void> theAppIsRunningWithAConfiguredVault(WidgetTester tester) async {
  await setUpWorld(tester, configured: true);
  await pumpApp(tester);
  // Configured vault: the app must boot on the Explorer surface.
  expect(find.byKey(const Key('notes-search-bar')), findsOneWidget);
}
