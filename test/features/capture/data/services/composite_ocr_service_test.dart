import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/features/capture/data/services/composite_ocr_service.dart';
import 'package:second_brain/features/capture/data/services/host_platform.dart';
import 'package:second_brain/features/capture/data/services/macos_vision_ocr_backend.dart';
import 'package:second_brain/features/capture/data/services/mlkit_ocr_backend.dart';
import 'package:second_brain/features/capture/data/services/tesseract_cli_ocr_backend.dart';

class MockMlKitOcrBackend extends Mock implements MlKitOcrBackend {}

class MockMacosVisionOcrBackend extends Mock implements MacosVisionOcrBackend {}

class MockTesseractCliOcrBackend extends Mock
    implements TesseractCliOcrBackend {}

void main() {
  late MockMlKitOcrBackend mlKit;
  late MockMacosVisionOcrBackend macosVision;
  late MockTesseractCliOcrBackend tesseract;
  late CompositeOcrService service;

  setUp(() {
    mlKit = MockMlKitOcrBackend();
    macosVision = MockMacosVisionOcrBackend();
    tesseract = MockTesseractCliOcrBackend();
    service = CompositeOcrService(
      const HostPlatform(),
      mlKit,
      macosVision,
      tesseract,
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('routes Android to ML Kit', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    when(
      () => mlKit.recognize('/tmp/img.png'),
    ).thenAnswer((_) async => 'déjà vu');

    expect(await service.recognizeText('/tmp/img.png'), 'déjà vu');
    verifyNever(() => macosVision.recognize(any()));
    verifyNever(() => tesseract.recognize(any()));
  });

  test('routes iOS to ML Kit', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    when(
      () => mlKit.recognize('/tmp/img.png'),
    ).thenAnswer((_) async => 'texte');

    expect(await service.recognizeText('/tmp/img.png'), 'texte');
  });

  test('routes macOS to the Vision method channel backend', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    when(
      () => macosVision.recognize('/tmp/img.png'),
    ).thenAnswer((_) async => 'texte vision');

    expect(await service.recognizeText('/tmp/img.png'), 'texte vision');
    verifyNever(() => mlKit.recognize(any()));
    verifyNever(() => tesseract.recognize(any()));
  });

  test('routes Windows to the tesseract CLI backend', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    when(
      () => tesseract.recognize('/tmp/img.png'),
    ).thenAnswer((_) async => 'texte tesseract');

    expect(await service.recognizeText('/tmp/img.png'), 'texte tesseract');
    verifyNever(() => mlKit.recognize(any()));
    verifyNever(() => macosVision.recognize(any()));
  });

  test('routes Linux to the tesseract CLI backend', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    when(
      () => tesseract.recognize('/tmp/img.png'),
    ).thenAnswer((_) async => 'texte tesseract');

    expect(await service.recognizeText('/tmp/img.png'), 'texte tesseract');
  });

  test('throws OcrException on an unsupported platform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

    expect(
      () => service.recognizeText('/tmp/img.png'),
      throwsA(isA<OcrException>()),
    );
  });
}
