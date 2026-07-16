import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/domain/services/clipboard_service.dart';

import 'bdd_world.dart';

/// Usage: the clipboard contains a note about {'les jardins partagés'}
///
/// Seeds the fake clipboard with a short note whose first line is
/// `Note copiée sur $param1` — with the default (prose) fake AI answer,
/// the intake falls back on that first line as the proposed title.
Future<void> theClipboardContainsANoteAbout(
  WidgetTester tester,
  String param1,
) async {
  fakeClipboardService.content = ClipboardContent(
    text:
        'Note copiée sur $param1\n'
        'Le paragraphe copié explique pourquoi $param1 méritent une '
        'place dans le jardin de notes.',
  );
}
