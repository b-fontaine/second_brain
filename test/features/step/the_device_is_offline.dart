import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the device is offline
Future<void> theDeviceIsOffline(WidgetTester tester) async {
  fakeNetworkInfo.setOnline(false);
  // Deliver the connectivity event to the sync listeners and repaint.
  await tester.pump();
}
