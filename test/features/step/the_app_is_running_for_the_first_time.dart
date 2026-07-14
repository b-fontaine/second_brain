import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/setup/presentation/pages/setup_page.dart';

import 'bdd_world.dart';

/// Usage: the app is running for the first time
Future<void> theAppIsRunningForTheFirstTime(WidgetTester tester) async {
  await setUpWorld(tester, configured: false);
  await pumpApp(tester);
  // No vault configured: the global redirect must land on onboarding.
  expect(find.byType(SetupPage), findsOneWidget);
}
