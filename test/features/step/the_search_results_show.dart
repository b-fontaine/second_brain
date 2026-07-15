import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the search results show {'Concept A'}
///
/// While a query is active the Explorer floats its results under the
/// search bar (search mode).
Future<void> theSearchResultsShow(WidgetTester tester, String param1) async {
  final results = find.byKey(const Key('explorer-search-results'));
  expect(
    results,
    findsOneWidget,
    reason: 'The floating search results should be visible during a search',
  );
  expect(
    find.descendant(of: results, matching: find.text(param1)),
    findsWidgets,
    reason: "The search results should list the note titled '$param1'",
  );
}
