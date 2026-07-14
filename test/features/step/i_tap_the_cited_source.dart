import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: I tap the cited source {'Mémoire de travail'}
///
/// Taps the citation [ActionChip] (labelled with the zettel id) under the
/// assistant answer, which pushes the note's reading route.
Future<void> iTapTheCitedSource(WidgetTester tester, String param1) async {
  final zettel = await worldRequireZettelByTitle(param1);
  final chip = find.widgetWithText(ActionChip, zettel.id.value);
  expect(
    chip,
    findsOneWidget,
    reason: "A source chip for '$param1' should be visible",
  );
  await tester.tap(chip);
  await tester.pumpAndSettle();
}
