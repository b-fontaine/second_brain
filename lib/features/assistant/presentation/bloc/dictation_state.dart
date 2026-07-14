import 'package:equatable/equatable.dart';

/// State of the voice input of a chat question.
sealed class DictationState extends Equatable {
  const DictationState();

  @override
  List<Object?> get props => const [];
}

/// Microphone off, no dictation in progress.
final class DictationIdle extends DictationState {
  const DictationIdle();
}

/// Microphone on, [transcript] grows as segments arrive.
final class DictationRecording extends DictationState {
  const DictationRecording(this.transcript);

  final String transcript;

  @override
  List<Object?> get props => [transcript];
}

/// Microphone stopped, the engine finalizes pending segments.
final class DictationTranscribing extends DictationState {
  const DictationTranscribing(this.transcript);

  final String transcript;

  @override
  List<Object?> get props => [transcript];
}

/// Dictation completed; [transcript] is ready to be inserted in the input.
final class DictationFinished extends DictationState {
  const DictationFinished(this.transcript);

  final String transcript;

  @override
  List<Object?> get props => [transcript];
}

/// Dictation could not start or failed mid-way.
final class DictationError extends DictationState {
  const DictationError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
