import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/presentation/widgets/extracted_text_view.dart';

import 'bdd_world.dart';
import 'i_import_the_audio_file.dart';
import 'i_tap_the_capture_button.dart';

/// Usage: a transcript of an audio note about {'les boucles de rétroaction'}
///
/// Opens the Capturer tab and imports an audio file whose (fake) transcript
/// talks about the topic, landing on the transcript review screen.
Future<void> aTranscriptOfAnAudioNoteAbout(
  WidgetTester tester,
  String param1,
) async {
  await iTapTheCaptureButton(tester);
  fakeTranscriptionService.scriptedTranscript =
      'Note audio à propos de $param1.\n'
      'L’enregistrement détaille pourquoi $param1 mérite une note '
      'dédiée dans le Zettelkasten.';
  await iImportTheAudioFile(tester, 'note_audio.m4a');
  expect(
    find.byType(ExtractedTextView),
    findsOneWidget,
    reason: 'The transcript should be up for review',
  );
}
