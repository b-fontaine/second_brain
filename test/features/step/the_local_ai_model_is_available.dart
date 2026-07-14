import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the local AI model is available
Future<void> theLocalAiModelIsAvailable(WidgetTester tester) async {
  fakeLocalAiService.modelReady = true;
}
