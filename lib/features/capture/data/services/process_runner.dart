import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';

/// Thin injectable wrapper around [Process.run] so command-line tools
/// (e.g. the tesseract CLI) can be mocked in tests.
@lazySingleton
class ProcessRunner {
  const ProcessRunner();

  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) {
    return Process.run(
      executable,
      arguments,
      stdoutEncoding: stdoutEncoding ?? systemEncoding,
      stderrEncoding: stderrEncoding ?? systemEncoding,
    );
  }
}
