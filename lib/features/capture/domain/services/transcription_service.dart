/// A piece of live-dictation transcript.
class DictationSegment {
  const DictationSegment(this.text, {required this.isFinal});

  final String text;

  /// False while the engine may still revise this segment.
  final bool isFinal;
}

/// Offline speech-to-text, for both recorded files and live dictation.
///
/// Throws [TranscriptionException] on engine errors.
abstract interface class TranscriptionService {
  /// True when the STT model is installed and ready.
  Future<bool> isReady();

  /// Downloads/installs the STT model. Emits progress 0.0 → 1.0.
  Stream<double> installModel();

  /// Transcribes a recorded audio file (m4a/wav/mp3...).
  Future<String> transcribeFile(String path);

  /// Starts microphone dictation, streaming partial then final segments.
  Stream<DictationSegment> startDictation();

  /// Stops the microphone and finalizes pending segments.
  Future<void> stopDictation();
}
