import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the transcript is shown for review
///
/// Review screen: « Fichier audio » source badge, editable field pre-filled
/// with the transcript, and the assistant action available.
Future<void> theTranscriptIsShownForReview(WidgetTester tester) async {
  expect(
    find.widgetWithText(Chip, 'Fichier audio'),
    findsOneWidget,
    reason: 'The capture source badge should say « Fichier audio »',
  );
  final field = tester.widget<TextField>(find.byType(TextField));
  expect(
    field.controller?.text,
    fakeTranscriptionService.scriptedTranscript,
    reason: 'The review field should be pre-filled with the transcript',
  );
  expect(
    find.text('Organiser avec l’assistant'),
    findsOneWidget,
    reason: 'The reviewed transcript can be handed to the assistant',
  );
}
