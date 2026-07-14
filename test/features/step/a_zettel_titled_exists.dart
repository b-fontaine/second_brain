import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: a zettel titled {'Concept B'} exists
Future<void> aZettelTitledExists(WidgetTester tester, String param1) async {
  await worldCreateZettel(param1, body: 'Note de test décrivant « $param1 ».');
  // Let the vault-change notification refresh any visible list.
  await tester.pumpAndSettle();
}
