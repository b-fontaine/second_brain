import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the OCR engine reads {'Croquis du plan de rotation des cultures'}
///
/// Scripts the fake OCR engine: the next recognized image yields a text
/// whose first line is the given content — with the default (prose) fake
/// AI answer, the intake falls back on that first line as the proposed
/// title.
Future<void> theOcrEngineReads(WidgetTester tester, String param1) async {
  fakeOcrService.scriptedText =
      '$param1\n'
      'Le document précise les étapes à suivre et les parcelles '
      'concernées.';
}
