import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the pollination section suggests {'Attention sélective'}
///
/// « Pollinisation — notes proches » : the card keyed `pollination-<id>`
/// surfaces the RAG suggestion (keyword fallback in BDD, so the subtitle
/// shows a rank, not a score). Suggestions load right after the note, and
/// the section sits below the fold: scroll the reading panel to it.
Future<void> thePollinationSectionSuggests(
  WidgetTester tester,
  String param1,
) async {
  final suggested = await worldRequireZettelByTitle(param1);
  final card = find.byKey(Key('pollination-${suggested.id.value}'));
  await tester.scrollUntilVisible(
    card,
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
    find.text('Pollinisation — notes proches'),
    findsOneWidget,
    reason: 'The Pollinisation section header should be visible',
  );
  expect(
    find.descendant(of: card, matching: find.text(param1)),
    findsOneWidget,
    reason: "A Pollinisation card should suggest '$param1'",
  );
}
