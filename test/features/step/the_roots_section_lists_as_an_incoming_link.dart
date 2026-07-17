import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the roots section lists {'Racine mère'} as an incoming link
///
/// « Racines — liens de la note » : the row keyed `root-link-<id>` carries
/// the backlink's title and the « Lien entrant » direction. The reading
/// panel scrolls (lazy ListView), so the row is scrolled into view first.
Future<void> theRootsSectionListsAsAnIncomingLink(
  WidgetTester tester,
  String param1,
) async {
  final source = await worldRequireZettelByTitle(param1);
  final row = find.byKey(Key('root-link-${source.id.value}'));
  await tester.scrollUntilVisible(
    row,
    120,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('zettel-reading-panel')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
  expect(
    find.descendant(of: row, matching: find.text(param1)),
    findsOneWidget,
    reason: "The Racines row should carry the title '$param1'",
  );
  expect(
    find.descendant(of: row, matching: find.text('Lien entrant')),
    findsOneWidget,
    reason: "The Racines row for '$param1' should be an incoming link",
  );
}
