import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/presentation/widgets/zettel_list_tile.dart';

/// Usage: the note list shows a tile titled {'Concept A'}
///
/// The chronological list of the raised Explorer sheet renders one
/// [ZettelListTile] per note.
Future<void> theNoteListShowsATileTitled(
  WidgetTester tester,
  String param1,
) async {
  expect(
    find.widgetWithText(ZettelListTile, param1),
    findsOneWidget,
    reason: "The note list should show a tile titled '$param1'",
  );
}
