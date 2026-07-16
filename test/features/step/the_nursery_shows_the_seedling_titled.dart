import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the nursery shows the seedling titled {'Semis sous serre froide'}
///
/// A card of the nursery list displays this proposed title. `findsWidgets`
/// on purpose: when the raw text is a single line (dictation), the title
/// and the excerpt of the card are the same string.
Future<void> theNurseryShowsTheSeedlingTitled(
  WidgetTester tester,
  String param1,
) async {
  final list = find.byKey(const Key('pepiniere-list'));
  expect(
    list,
    findsOneWidget,
    reason: 'The nursery should display its seedling list',
  );
  expect(
    find.descendant(of: list, matching: find.text(param1)),
    findsWidgets,
    reason: 'A nursery card should be titled « $param1 »',
  );
}
