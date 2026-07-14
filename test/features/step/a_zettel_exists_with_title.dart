import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: a zettel exists with title {'Mémoire de travail'}
Future<void> aZettelExistsWithTitle(WidgetTester tester, String param1) async {
  // Assertion step: the note must already be in the vault. It also becomes
  // `worldLastZettel` for the follow-up "the zettel ..." assertions.
  final zettel = await worldRequireZettelByTitle(param1);
  expect(zettel.title, param1);
}
