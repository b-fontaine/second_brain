import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/presentation/widgets/zettel_list_tile.dart';

/// Usage: I open the zettel titled {'Concept A'}
///
/// Taps the note's row in the home list (scoped to [ZettelListTile] so the
/// search bar's text never shadows the tile), which navigates to the
/// reading screen in compact layouts.
Future<void> iOpenTheZettelTitled(WidgetTester tester, String param1) async {
  final tile = find.descendant(
    of: find.byType(ZettelListTile),
    matching: find.text(param1),
  );
  expect(
    tile,
    findsOneWidget,
    reason: "The note list should show a tile titled '$param1'",
  );
  await tester.tap(tile);
  await tester.pumpAndSettle();
}
