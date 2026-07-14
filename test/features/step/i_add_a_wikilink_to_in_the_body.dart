import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: I add a wikilink to {'Concept B'} in the body
///
/// If the note is currently open in reading mode, switches to the editor
/// first, then appends `[[targetId|targetTitle]]` to the body field.
Future<void> iAddAWikilinkToInTheBody(
  WidgetTester tester,
  String param1,
) async {
  final target = await worldRequireZettelByTitle(param1);

  var bodyField = find.byKey(const Key('note-body-field'));
  if (bodyField.evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key('edit-note-button')));
    await tester.pumpAndSettle();
    bodyField = find.byKey(const Key('note-body-field'));
  }
  expect(bodyField, findsOneWidget);

  final currentBody = tester.widget<TextField>(bodyField).controller!.text;
  final link = '[[${target.id.value}|${target.title}]]';
  await tester.enterText(
    bodyField,
    currentBody.trim().isEmpty ? link : '$currentBody\n\n$link',
  );
  await tester.pump();
}
