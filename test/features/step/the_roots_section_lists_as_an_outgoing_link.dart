import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the roots section lists {'Feuille fille'} as an outgoing link
///
/// « Racines — liens de la note » : the row keyed `root-link-<id>` carries
/// the neighbor's title and the « Lien sortant » direction. The reading
/// panel scrolls (lazy ListView), so the row is scrolled into view first.
Future<void> theRootsSectionListsAsAnOutgoingLink(
  WidgetTester tester,
  String param1,
) async {
  final target = await worldRequireZettelByTitle(param1);
  final row = find.byKey(Key('root-link-${target.id.value}'));
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
    find.descendant(of: row, matching: find.text('Lien sortant')),
    findsOneWidget,
    reason: "The Racines row for '$param1' should be an outgoing link",
  );
}
