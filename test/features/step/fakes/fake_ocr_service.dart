import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/features/capture/domain/services/ocr_service.dart';

/// Scriptable OCR engine.
///
/// Scripting: set [available] true (done by the step "the local OCR engine
/// is available") and put the text to "recognize" in [scriptedText].
/// [recognizedImages] records every image path passed in.
class FakeOcrService implements OcrService {
  bool available = false;

  String scriptedText = '';

  final List<String> recognizedImages = [];

  @override
  Future<String> recognizeText(String imagePath) async {
    if (!available) {
      throw const OcrException('Moteur OCR non disponible (fake)');
    }
    recognizedImages.add(imagePath);
    return scriptedText;
  }
}
