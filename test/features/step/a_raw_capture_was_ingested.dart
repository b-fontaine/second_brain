import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: a raw capture {'Texte brut capturé'} was ingested
Future<void> aRawCaptureWasIngested(WidgetTester tester, String param1) async {
  await worldAddInboxItem(param1);
  await tester.pumpAndSettle();
}
