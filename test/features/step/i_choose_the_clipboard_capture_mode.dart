import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/domain/services/clipboard_service.dart';

import 'bdd_world.dart';

/// Usage: I choose the clipboard capture mode
///
/// Taps the « Presse-papiers » source card. When no Given scripted the fake
/// clipboard, a default text is seeded first: the machine's real clipboard
/// is obviously not usable inside a widget test.
Future<void> iChooseTheClipboardCaptureMode(WidgetTester tester) async {
  if (fakeClipboardService.content.isEmpty) {
    fakeClipboardService.content = const ClipboardContent(
      text:
          'Contenu copié depuis un article : les notes atomiques rendent '
          'la connaissance réutilisable.',
    );
  }
  final card = find.text('Presse-papiers');
  expect(card, findsOneWidget);
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
}
