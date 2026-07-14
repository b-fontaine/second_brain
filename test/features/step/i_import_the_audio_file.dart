import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';

import 'bdd_world.dart';

/// Usage: I import the audio file {'meeting.m4a'}
///
/// The « Ajouter un fichier » chip hard-calls the native file picker
/// (`file_selector.openFile` via `seedByFile`, no injectable wrapper),
/// which cannot run in a widget test. This step therefore performs the
/// picker callback itself: it pushes the capture flow primed with
/// [CaptureAudioFilePicked] — the exact event `pickCaptureFileEvent` maps
/// an audio selection to (see [worldSeedCaptureFlow]). A default transcript
/// is seeded when no Given scripted one.
Future<void> iImportTheAudioFile(WidgetTester tester, String param1) async {
  if (fakeTranscriptionService.scriptedTranscript.isEmpty) {
    fakeTranscriptionService.scriptedTranscript =
        'Compte rendu de la réunion : décisions prises et prochaines '
        'étapes à planifier.';
  }
  await worldSeedCaptureFlow(tester, CaptureAudioFilePicked(param1));
}
