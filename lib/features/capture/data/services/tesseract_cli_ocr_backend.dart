import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import 'host_platform.dart';
import 'ocr_backend.dart';
import 'process_runner.dart';

/// Windows/Linux OCR via the system `tesseract` CLI (`fra+eng`).
///
/// When tesseract is missing, throws an [OcrException] whose message tells
/// the user how to install it on their platform.
@lazySingleton
class TesseractCliOcrBackend implements OcrBackend {
  const TesseractCliOcrBackend(this._runner, this._platform);

  final ProcessRunner _runner;
  final HostPlatform _platform;

  Future<bool> isAvailable() async {
    try {
      final result = await _runner.run('tesseract', const ['--version']);
      return result.exitCode == 0;
    } on Exception {
      return false;
    }
  }

  String get _installInstructions => _platform.target == TargetPlatform.windows
      ? "Tesseract n'est pas installé. Téléchargez l'installateur depuis "
            'https://github.com/UB-Mannheim/tesseract/wiki en cochant les '
            'langues « French » et « English », vérifiez que tesseract.exe '
            "est dans le PATH, puis relancez l'application."
      : "Tesseract n'est pas installé. Installez-le avec : "
            'sudo apt install tesseract-ocr tesseract-ocr-fra '
            'tesseract-ocr-eng (Debian/Ubuntu) ou : sudo dnf install '
            'tesseract tesseract-langpack-fra (Fedora), puis relancez '
            "l'application.";

  @override
  Future<String> recognize(String imagePath) async {
    if (!await isAvailable()) {
      throw OcrException(_installInstructions);
    }
    final result = await _runner.run(
      'tesseract',
      [imagePath, 'stdout', '-l', 'fra+eng', '--psm', '3'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw OcrException(
        'tesseract a échoué (code ${result.exitCode}) : ${result.stderr}',
      );
    }
    return (result.stdout as String).trim();
  }
}
