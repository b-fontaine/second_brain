import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: I weave the pollination suggestion {'Attention sélective'}
///
/// Taps the « Tisser » action (key `weave-<id>`) of the Pollinisation card:
/// the detail cubit appends `[[id|titre]]` to the note body, saves and
/// reloads (brief Loading pass; pumpAndSettle terminates, nothing animates
/// forever on this screen).
Future<void> iWeaveThePollinationSuggestion(
  WidgetTester tester,
  String param1,
) async {
  final suggested = await worldRequireZettelByTitle(param1);
  final weaveButton = find.byKey(Key('weave-${suggested.id.value}'));
  await tester.scrollUntilVisible(
    weaveButton,
    120,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('zettel-reading-panel')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
  await tester.tap(weaveButton);
  await tester.pumpAndSettle();
}
