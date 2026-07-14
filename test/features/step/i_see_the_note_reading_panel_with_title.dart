import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the note reading panel with title {'Concept A'}
///
/// The reading panel is the ListView tagged `zettel-reading-panel`
/// (rendered by both the detail page and the expanded side panels).
Future<void> iSeeTheNoteReadingPanelWithTitle(
  WidgetTester tester,
  String param1,
) async {
  final panel = find.byKey(const Key('zettel-reading-panel'));
  expect(panel, findsOneWidget);
  expect(
    find.descendant(of: panel, matching: find.text(param1)),
    findsWidgets,
    reason: "The reading panel should display the title '$param1'",
  );
}
