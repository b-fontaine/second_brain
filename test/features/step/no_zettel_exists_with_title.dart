import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: no zettel exists with title {'Taille des rosiers anciens'}
///
/// Composting must never create a note: the vault holds no zettel with
/// this title.
Future<void> noZettelExistsWithTitle(WidgetTester tester, String param1) async {
  final zettel = await worldGetZettelByTitle(param1);
  expect(
    zettel,
    isNull,
    reason: "No zettel titled '$param1' should exist in the vault",
  );
}
