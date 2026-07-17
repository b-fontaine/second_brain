import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the answer cites the zettel {'Mémoire de travail'} as source
///
/// Citations are rendered as [ActionChip]s labelled with the cited note's
/// title under the assistant bubble; the chip for the note titled [param1]
/// must be visible.
Future<void> theAnswerCitesTheZettelAsSource(
  WidgetTester tester,
  String param1,
) async {
  final zettel = await worldRequireZettelByTitle(param1);
  final chip = find.widgetWithText(ActionChip, zettel.title);
  expect(
    chip,
    findsOneWidget,
    reason:
        "The answer should show a source chip for '$param1' "
        '(id ${zettel.id.value})',
  );
}
