import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the local OCR engine is available
Future<void> theLocalOcrEngineIsAvailable(WidgetTester tester) async {
  fakeOcrService.available = true;
}
