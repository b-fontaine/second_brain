import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';

/// Scriptable offline speech-to-text.
///
/// Scripting: set [ready] true (done by the step "the local transcription
/// engine is available"); put the expected file transcript in
/// [scriptedTranscript] and live-dictation output in [scriptedSegments].
/// [transcribedFiles] records every transcribed path.
class FakeTranscriptionService implements TranscriptionService {
  bool ready = false;

  String scriptedTranscript = '';

  List<DictationSegment> scriptedSegments = [];

  final List<String> transcribedFiles = [];

  bool dictating = false;

  @override
  Future<bool> isReady() async => ready;

  @override
  Stream<double> installModel() async* {
    yield 0.5;
    ready = true;
    yield 1.0;
  }

  @override
  Future<String> transcribeFile(String path) async {
    _ensureReady();
    transcribedFiles.add(path);
    return scriptedTranscript;
  }

  @override
  Stream<DictationSegment> startDictation() async* {
    _ensureReady();
    dictating = true;
    for (final segment in scriptedSegments) {
      yield segment;
    }
  }

  @override
  Future<void> stopDictation() async {
    dictating = false;
  }

  void _ensureReady() {
    if (!ready) {
      throw const TranscriptionException(
        'Moteur de transcription non installé (fake)',
      );
    }
  }
}
