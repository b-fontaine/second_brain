import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';

import 'bdd_world.dart';
import 'fakes/capture_live_fake_transcription_service.dart';

/// Usage: I speak {'ceci est une note dictée'}
///
/// Pushes a final utterance into the LIVE dictation stream (the
/// [CaptureLiveFakeTranscriptionService] installed by "I tap the capture
/// button") and checks the words appear in the live transcript.
Future<void> iSpeak(WidgetTester tester, String param1) async {
  final service = fakeTranscriptionService;
  expect(
    service,
    isA<CaptureLiveFakeTranscriptionService>(),
    reason: '"I tap the capture button" installs the live dictation fake',
  );
  (service as CaptureLiveFakeTranscriptionService).emitSegment(
    DictationSegment(param1, isFinal: true),
  );
  // Deliver the stream event, then rebuild with the new transcript.
  await tester.pump();
  await tester.pump();
  expect(
    find.textContaining(param1),
    findsWidgets,
    reason: 'The spoken words should appear in the live transcript',
  );
}
