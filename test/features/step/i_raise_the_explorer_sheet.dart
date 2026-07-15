import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I raise the explorer sheet
///
/// Drags the persistent bottom sheet of the Explorer surface up by its
/// handle, revealing the chronological note list (list state).
Future<void> iRaiseTheExplorerSheet(WidgetTester tester) async {
  final handle = find.byKey(const Key('explorer-sheet-handle'));
  expect(
    handle,
    findsOneWidget,
    reason: 'The Explorer sheet handle should be visible',
  );
  await tester.drag(handle, const Offset(0, -600));
  // Bounded pumps only: the constellation ticker may still be live, which
  // rules out pumpAndSettle while the sheet snaps into place.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
