import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I create a zettel titled {'Note en ligne'}
///
/// User-facing creation: FAB -> title -> save, exactly like a real user, so
/// the vault-change notification reaches the `SyncOrchestrator`. Its 2 s
/// debounce is then crossed with a bounded pump (fake async clock, no real
/// sleep) so the automatic commit — and, when online, the push — happens
/// before the next step asserts.
Future<void> iCreateAZettelTitled(WidgetTester tester, String param1) async {
  await tester.tap(find.byKey(const Key('new-note-fab')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('note-title-field')), param1);
  await tester.pump();

  await tester.tap(find.byKey(const Key('save-note-button')));
  await tester.pumpAndSettle();

  // Past the orchestrator's 2 s debounce: fires the auto commit-then-sync.
  await tester.pump(const Duration(seconds: 3));
  // Render the sync status emitted by the commit/push.
  await tester.pump();
}
