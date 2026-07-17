import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the note shows its mini constellation
///
/// The reading view opens on the static 1-hop constellation (center note +
/// neighbors, zero animation); it is only built when the note has at least
/// one link.
Future<void> theNoteShowsItsMiniConstellation(WidgetTester tester) async {
  expect(
    find.byKey(const Key('mini-constellation')),
    findsOneWidget,
    reason:
        'A linked note should open on its 1-hop mini-constellation '
        '(hidden only when the note has no link)',
  );
}
