import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import 'ocr_backend.dart';

/// macOS OCR via a method channel to the native Vision framework
/// (VNRecognizeTextRequest). The Swift side is registered in
/// macos/Runner and handles the `recognize` method.
@lazySingleton
class MacosVisionOcrBackend implements OcrBackend {
  const MacosVisionOcrBackend();

  static const MethodChannel _channel = MethodChannel(
    'fr.benoitfontaine.second_brain/ocr',
  );

  @override
  Future<String> recognize(String imagePath) async {
    try {
      final text = await _channel.invokeMethod<String>('recognize', {
        'path': imagePath,
        'languages': ['fr-FR', 'en-US'],
      });
      return (text ?? '').trim();
    } on PlatformException catch (e) {
      throw OcrException(
        "Échec de l'OCR macOS (Vision) : ${e.message ?? e.code}",
      );
    } on MissingPluginException {
      throw const OcrException(
        "Le module natif d'OCR macOS n'est pas disponible dans cette "
        'version de l\'application',
      );
    }
  }
}
