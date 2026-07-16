import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: I import the audio file {'ruches_urbaines.m4a'}
///
/// The « Ajouter un fichier » chip hard-calls the native file picker
/// (`file_selector.openFile` via `seedByFile`, no injectable wrapper),
/// which cannot run in a widget test. This step therefore performs the
/// picker callback itself: it opens the « aperçu avant semis » preview
/// primed with the picked path (see [worldOpenSeedPreview]); the intake
/// detects the audio extension and transcribes through the fake engine.
/// A default transcript is seeded when no Given scripted one.
Future<void> iImportTheAudioFile(WidgetTester tester, String param1) async {
  if (fakeTranscriptionService.scriptedTranscript.isEmpty) {
    fakeTranscriptionService.scriptedTranscript =
        'Compte rendu de la réunion : décisions prises et prochaines '
        'étapes à planifier.';
  }
  await worldOpenSeedPreview(tester, param1);
}
