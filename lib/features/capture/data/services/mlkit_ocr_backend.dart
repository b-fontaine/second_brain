import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import 'ocr_backend.dart';

/// Android/iOS OCR via on-device ML Kit text recognition.
///
/// [TextRecognitionScript.latin] covers French including accents.
@lazySingleton
class MlKitOcrBackend implements OcrBackend {
  const MlKitOcrBackend();

  @override
  Future<String> recognize(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return result.text.trim();
    } on OcrException {
      rethrow;
    } on Exception catch (e) {
      throw OcrException('Échec de la reconnaissance de texte (ML Kit) : $e');
    } finally {
      await recognizer.close();
    }
  }
}
