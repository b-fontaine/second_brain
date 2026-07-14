import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';

import 'bdd_world.dart';

/// Usage: I import the image file {'slide.png'}
///
/// The « Ajouter un fichier » chip hard-calls the native pickers
/// (`file_selector` / `ImagePicker` via `seedByFile`, no injectable
/// wrapper), which cannot run in a widget test. This step therefore
/// performs the picker callback itself: it pushes the capture flow primed
/// with [CaptureScreenshotPicked] — the exact event `pickCaptureFileEvent`
/// maps an image selection to (see [worldSeedCaptureFlow]). A default OCR
/// text is seeded when no Given scripted one.
Future<void> iImportTheImageFile(WidgetTester tester, String param1) async {
  if (fakeOcrService.scriptedText.isEmpty) {
    fakeOcrService.scriptedText =
        'Texte reconnu sur la diapositive : principes d’architecture et '
        'bonnes pratiques.';
  }
  await worldSeedCaptureFlow(tester, CaptureScreenshotPicked(param1));
}
