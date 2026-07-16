import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/explorer/presentation/pages/explorer_page.dart';

/// Usage: the explorer confirms the seeding
///
/// After a sowing the app lands back on the Explorer surface with the
/// confirmation SnackBar. Both seeding paths share the same functional
/// wording: « Semis déposé en pépinière — brouillon à valider. » (preview)
/// and « Semé en pépinière — brouillon à valider. » (dictation stop).
Future<void> theExplorerConfirmsTheSeeding(WidgetTester tester) async {
  expect(
    find.byType(ExplorerPage),
    findsOneWidget,
    reason: 'The app should be back on the Explorer surface',
  );
  expect(
    find.textContaining('en pépinière — brouillon à valider'),
    findsOneWidget,
    reason: 'The nursery confirmation SnackBar should be visible',
  );
}
