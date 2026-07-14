import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the local transcription engine is available
Future<void> theLocalTranscriptionEngineIsAvailable(WidgetTester tester) async {
  fakeTranscriptionService.ready = true;
}
