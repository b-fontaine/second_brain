import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';

import 'bdd_world.dart';

/// Usage: I ask by voice {'Que sais-je sur la mémoire de travail ?'}
///
/// Scripts the fake transcription engine to dictate [param1], taps the
/// microphone button of the chat input bar (the scripted dictation stream
/// finishes on its own, prefilling the transcript into the question field),
/// then sends the question.
Future<void> iAskByVoice(WidgetTester tester, String param1) async {
  fakeTranscriptionService.scriptedSegments = [
    DictationSegment(param1, isFinal: true),
  ];

  await tester.tap(find.byIcon(Icons.mic_none));
  await tester.pumpAndSettle();

  // The dictated transcript must have landed in the input field.
  expect(
    find.widgetWithText(TextField, param1),
    findsOneWidget,
    reason: 'The dictated transcript should prefill the question field',
  );

  await tester.tap(find.byTooltip('Envoyer'));
  await tester.pumpAndSettle();
}
