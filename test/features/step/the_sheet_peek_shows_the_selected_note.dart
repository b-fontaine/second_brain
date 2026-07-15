import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the sheet peek shows the selected note {'Concept A'}
///
/// After a node selection the persistent Explorer sheet rises to its
/// summary position: title of the selected note plus the « Ouvrir »
/// action. The title may also appear in the list rows below the summary,
/// hence the non-strict count.
Future<void> theSheetPeekShowsTheSelectedNote(
  WidgetTester tester,
  String param1,
) async {
  final sheet = find.byKey(const Key('explorer-sheet'));
  expect(
    sheet,
    findsOneWidget,
    reason: 'The Explorer sheet should be mounted',
  );
  expect(
    find.descendant(of: sheet, matching: find.text(param1)),
    findsWidgets,
    reason: "The sheet peek should display the title '$param1'",
  );
  expect(
    find.descendant(
      of: sheet,
      matching: find.byKey(const Key('explorer-open-note')),
    ),
    findsOneWidget,
    reason: 'The selection summary should offer the « Ouvrir » action',
  );
}
