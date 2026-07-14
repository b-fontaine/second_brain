import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the device is online
Future<void> theDeviceIsOnline(WidgetTester tester) async {
  fakeNetworkInfo.setOnline(true);
  // Deliver the connectivity event to the sync listeners and repaint.
  await tester.pump();
}
