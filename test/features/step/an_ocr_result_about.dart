import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/presentation/widgets/extracted_text_view.dart';

import 'bdd_world.dart';
import 'i_import_the_image_file.dart';
import 'i_tap_the_capture_button.dart';

/// Usage: an OCR result about {'l architecture hexagonale'}
///
/// Opens the Capturer tab and imports an image whose (fake) OCR output
/// talks about the topic, landing on the recognized-text review screen.
Future<void> anOcrResultAbout(WidgetTester tester, String param1) async {
  await iTapTheCaptureButton(tester);
  fakeOcrService.scriptedText =
      'Diapositive à propos de $param1.\n'
      'Le schéma explique comment $param1 structure les dépendances '
      'du projet.';
  await iImportTheImageFile(tester, 'diapositive_ocr.png');
  expect(
    find.byType(ExtractedTextView),
    findsOneWidget,
    reason: 'The recognized text should be up for review',
  );
}
