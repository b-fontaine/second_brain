import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';
import 'package:second_brain/features/capture/presentation/widgets/extracted_text_view.dart';

import 'bdd_world.dart';
import 'fakes/capture_live_fake_transcription_service.dart';
import 'i_choose_to_dictate.dart';
import 'i_tap_the_seed_button.dart';

/// Usage: a dictated transcript about {'la revue de code'}
///
/// Runs a whole (fake) dictation about the topic — seed dial, « Dicter »
/// chip, one final utterance, stop — landing on the transcript review
/// screen.
Future<void> aDictatedTranscriptAbout(
  WidgetTester tester,
  String param1,
) async {
  await iTapTheSeedButton(tester);

  // Scripted before the chip tap: the dictation starts as soon as the
  // capture flow is pushed, replaying these segments.
  fakeTranscriptionService.scriptedSegments = [
    DictationSegment(
      'Réflexion dictée à propos de $param1 avec quelques pistes '
      'concrètes à explorer.',
      isFinal: true,
    ),
  ];

  await iChooseToDictate(tester);

  // Let the microphone stream end, then stop. The bloc's stop handler
  // awaits an async* subscription cancel that only completes on the REAL
  // event loop, hence the runAsync hops (see i_stop_dictating.dart).
  (fakeTranscriptionService as CaptureLiveFakeTranscriptionService)
      .endDictationStream();
  await tester.pump();
  await tester.tap(find.text('Arrêter la dictée'));
  await tester.pump();
  for (
    var i = 0;
    i < 20 && find.text('Arrêter la dictée').evaluate().isNotEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();

  expect(
    find.byType(ExtractedTextView),
    findsOneWidget,
    reason: 'The dictated transcript should be up for review',
  );
}
