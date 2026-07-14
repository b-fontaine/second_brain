import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/features/capture/data/services/host_platform.dart';
import 'package:second_brain/features/capture/data/services/process_runner.dart';
import 'package:second_brain/features/capture/data/services/tesseract_cli_ocr_backend.dart';

class MockProcessRunner extends Mock implements ProcessRunner {}

void main() {
  late MockProcessRunner runner;
  late TesseractCliOcrBackend backend;

  setUp(() {
    runner = MockProcessRunner();
    backend = TesseractCliOcrBackend(runner, const HostPlatform());
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  void stubRuns({
    required ProcessResult versionResult,
    ProcessResult? recognizeResult,
  }) {
    when(
      () => runner.run(
        any(),
        any(),
        stdoutEncoding: any(named: 'stdoutEncoding'),
        stderrEncoding: any(named: 'stderrEncoding'),
      ),
    ).thenAnswer((invocation) async {
      final args = invocation.positionalArguments[1] as List<String>;
      if (args.contains('--version')) return versionResult;
      return recognizeResult ?? ProcessResult(9, 1, '', 'unexpected');
    });
  }

  test('runs tesseract with fra+eng on the image and trims stdout', () async {
    stubRuns(
      versionResult: ProcessResult(1, 0, 'tesseract 5.3.4', ''),
      recognizeResult: ProcessResult(2, 0, 'Bonjour déjà vu\n', ''),
    );

    final text = await backend.recognize('/tmp/capture.png');

    expect(text, 'Bonjour déjà vu');
    verify(
      () => runner.run(
        'tesseract',
        ['/tmp/capture.png', 'stdout', '-l', 'fra+eng', '--psm', '3'],
        stdoutEncoding: any(named: 'stdoutEncoding'),
        stderrEncoding: any(named: 'stderrEncoding'),
      ),
    ).called(1);
  });

  test('throws Linux install instructions when tesseract is missing', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    when(
      () => runner.run(
        any(),
        any(),
        stdoutEncoding: any(named: 'stdoutEncoding'),
        stderrEncoding: any(named: 'stderrEncoding'),
      ),
    ).thenThrow(const ProcessException('tesseract', ['--version']));

    expect(
      () => backend.recognize('/tmp/capture.png'),
      throwsA(
        isA<OcrException>().having(
          (e) => e.message,
          'message',
          contains('sudo apt install tesseract-ocr'),
        ),
      ),
    );
  });

  test(
    'throws Windows install instructions when tesseract is missing',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      stubRuns(versionResult: ProcessResult(1, 127, '', 'not found'));

      expect(
        () => backend.recognize('/tmp/capture.png'),
        throwsA(
          isA<OcrException>().having(
            (e) => e.message,
            'message',
            contains('UB-Mannheim'),
          ),
        ),
      );
    },
  );

  test('throws OcrException with stderr when recognition fails', () async {
    stubRuns(
      versionResult: ProcessResult(1, 0, 'tesseract 5.3.4', ''),
      recognizeResult: ProcessResult(
        2,
        1,
        '',
        'Error opening data file fra.traineddata',
      ),
    );

    expect(
      () => backend.recognize('/tmp/capture.png'),
      throwsA(
        isA<OcrException>().having(
          (e) => e.message,
          'message',
          contains('fra.traineddata'),
        ),
      ),
    );
  });
}
