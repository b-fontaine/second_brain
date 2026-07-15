import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/presentation/widgets/zettel_list_tile.dart';

/// Usage: I open the zettel titled {'Concept A'}
///
/// Taps the note's row (scoped to [ZettelListTile] so the search bar's text
/// never shadows the tile), which navigates to the reading screen in
/// compact layouts. On the fused Explorer surface the chronological list
/// lives in the bottom sheet: when no tile is visible yet (no active
/// search), the sheet is raised first by dragging its handle.
Future<void> iOpenTheZettelTitled(WidgetTester tester, String param1) async {
  Finder tile() => find.descendant(
    of: find.byType(ZettelListTile),
    matching: find.text(param1),
  );
  if (tile().evaluate().isEmpty) {
    final handle = find.byKey(const Key('explorer-sheet-handle'));
    expect(
      handle,
      findsOneWidget,
      reason:
          "No visible tile titled '$param1' and no Explorer sheet handle "
          'to reveal the note list',
    );
    await tester.drag(handle, const Offset(0, -600));
    // Bounded pumps only: the constellation ticker may still be live,
    // which rules out pumpAndSettle while the sheet snaps into place.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  expect(
    tile(),
    findsOneWidget,
    reason: "The note list should show a tile titled '$param1'",
  );
  await tester.tap(tile());
  await tester.pumpAndSettle();
}
