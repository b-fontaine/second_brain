import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/services/ocr_service.dart';
import 'host_platform.dart';
import 'macos_vision_ocr_backend.dart';
import 'mlkit_ocr_backend.dart';
import 'ocr_backend.dart';
import 'tesseract_cli_ocr_backend.dart';

/// [OcrService] that routes to the right engine per platform:
/// - Android/iOS → ML Kit text recognition (latin script);
/// - macOS → native Vision framework via method channel;
/// - Windows/Linux → system `tesseract` CLI (`fra+eng`).
@LazySingleton(as: OcrService)
class CompositeOcrService implements OcrService {
  const CompositeOcrService(
    this._platform,
    MlKitOcrBackend mlKit,
    MacosVisionOcrBackend macosVision,
    TesseractCliOcrBackend tesseract,
  ) : _mlKit = mlKit,
      _macosVision = macosVision,
      _tesseract = tesseract;

  final HostPlatform _platform;
  final OcrBackend _mlKit;
  final OcrBackend _macosVision;
  final OcrBackend _tesseract;

  @override
  Future<String> recognizeText(String imagePath) {
    final backend = switch (_platform.target) {
      TargetPlatform.android || TargetPlatform.iOS => _mlKit,
      TargetPlatform.macOS => _macosVision,
      TargetPlatform.windows || TargetPlatform.linux => _tesseract,
      _ => throw const OcrException(
        "L'OCR n'est pas pris en charge sur cette plateforme",
      ),
    };
    return backend.recognize(imagePath);
  }
}
