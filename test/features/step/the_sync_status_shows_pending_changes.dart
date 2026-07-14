import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the sync status shows pending changes
///
/// The AppBar `SyncStatusIndicator` renders the pendingPush state as an
/// IconButton whose tooltip mentions the pending "modification(s)"
/// ('N modification(s) à envoyer' online, 'Hors ligne — N modification(s)
/// en attente' offline) with the count in a badge.
Future<void> theSyncStatusShowsPendingChanges(WidgetTester tester) async {
  final pending = fakeGitSyncRepository.pendingCommits;
  expect(
    pending,
    greaterThan(0),
    reason: 'The repository should hold commits waiting to be pushed',
  );
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget is Tooltip &&
          (widget.message?.contains('modification(s)') ?? false),
    ),
    findsOneWidget,
    reason: 'The sync indicator should show pending modifications',
  );
  expect(
    find.descendant(of: find.byType(Badge), matching: find.text('$pending')),
    findsOneWidget,
    reason: 'The sync indicator badge should show the pending commit count',
  );
}
