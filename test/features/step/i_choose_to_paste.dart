import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/domain/services/clipboard_service.dart';

import 'bdd_world.dart';

/// Usage: I choose to paste
///
/// Taps the « Coller » chip of the seed dial, which closes the dial and
/// pushes the full-screen capture flow primed with the clipboard event.
/// When no Given scripted the fake clipboard, a default text is seeded
/// first: the machine's real clipboard is obviously not usable inside a
/// widget test.
Future<void> iChooseToPaste(WidgetTester tester) async {
  if (fakeClipboardService.content.isEmpty) {
    fakeClipboardService.content = const ClipboardContent(
      text:
          'Contenu copié depuis un article : les notes atomiques rendent '
          'la connaissance réutilisable.',
    );
  }
  final chip = find.byKey(const Key('seed-dial-paste'));
  expect(
    chip,
    findsOneWidget,
    reason: 'The seed dial should offer the « Coller » entry',
  );
  await tester.tap(chip);
  await tester.pumpAndSettle();
}
