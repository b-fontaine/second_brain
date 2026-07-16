import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: I import the image file {'plan_rotation.png'}
///
/// The « Ajouter un fichier » chip hard-calls the native pickers
/// (`file_selector` / `ImagePicker` via `seedByFile`, no injectable
/// wrapper), which cannot run in a widget test. This step therefore
/// performs the picker callback itself: it opens the « aperçu avant
/// semis » preview primed with the picked path (see
/// [worldOpenSeedPreview]); the intake detects the image extension and
/// runs the fake OCR engine. A default OCR text is seeded when no Given
/// scripted one.
Future<void> iImportTheImageFile(WidgetTester tester, String param1) async {
  if (fakeOcrService.scriptedText.isEmpty) {
    fakeOcrService.scriptedText =
        'Texte reconnu sur la diapositive : principes d’architecture et '
        'bonnes pratiques.';
  }
  await worldOpenSeedPreview(tester, param1);
}
