import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/domain/services/clipboard_service.dart';

import 'bdd_world.dart';

/// Usage: the clipboard contains a long article about {'la mémoire de travail'}
///
/// Seeds the fake clipboard with a two-paragraph article on the topic (the
/// fake LLM proposes one draft per paragraph) and creates two vault zettels
/// on the same topic, so the assistant's RAG index has existing related
/// notes to suggest as links for each draft.
Future<void> theClipboardContainsALongArticleAbout(
  WidgetTester tester,
  String param1,
) async {
  await worldCreateZettel(
    'Note existante sur $param1',
    body: 'Réflexion déjà capturée à propos de $param1.',
  );
  await worldCreateZettel(
    'Références autour de $param1',
    body: 'Sources et lectures qui traitent de $param1.',
  );
  await tester.pumpAndSettle();

  fakeClipboardService.content = ClipboardContent(
    text:
        'Première idée sur $param1\n'
        'Un long paragraphe qui explique en détail pourquoi $param1 '
        'joue un rôle central dans ce domaine.\n'
        '\n'
        'Seconde idée sur $param1\n'
        'Un autre paragraphe qui explore une facette complémentaire '
        'de $param1 et ses limites pratiques.',
  );
}
