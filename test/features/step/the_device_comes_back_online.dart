import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the device comes back online
Future<void> theDeviceComesBackOnline(WidgetTester tester) async {
  fakeNetworkInfo.setOnline(true);
  // Let the orchestrator react to the connectivity event (getStatus ->
  // synchronize) and the AppBar indicator repaint with the new status.
  await tester.pump();
  await tester.pumpAndSettle();
}
