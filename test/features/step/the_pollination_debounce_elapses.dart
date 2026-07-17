import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/presentation/pages/zettel_edit_page.dart';

/// Usage: the pollination debounce elapses
///
/// Crosses the editor's « fleur » debounce explicitly through the public
/// constant (never a real sleep): the timer fires, the RAG lookup resolves
/// and the banner — if a close note was found — renders.
Future<void> thePollinationDebounceElapses(WidgetTester tester) async {
  await tester.pump(ZettelEditPage.pollinationDebounce);
  await tester.pumpAndSettle();
}
