import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';
import 'fakes/capture_live_fake_transcription_service.dart';

/// Usage: I stop dictating
///
/// First lets the (fake) microphone stream end (see
/// [CaptureLiveFakeTranscriptionService.endDictationStream]), then taps the
/// stop button. The bloc's stop handler awaits the cancellation of its
/// dictation subscription — an `async*` stream whose cancel future only
/// completes on the REAL event loop — so short [WidgetTester.runAsync]
/// hops are interleaved with pumps until the review screen appears.
Future<void> iStopDictating(WidgetTester tester) async {
  final service = fakeTranscriptionService;
  if (service is CaptureLiveFakeTranscriptionService) {
    service.endDictationStream();
    await tester.pump();
  }
  final stop = find.text('Arrêter la dictée');
  expect(stop, findsOneWidget, reason: 'A dictation should be running');
  await tester.tap(stop);
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
}
