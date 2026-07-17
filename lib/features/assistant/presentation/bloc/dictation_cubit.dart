import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../capture/domain/services/transcription_service.dart';
import 'dictation_state.dart';

/// Drives voice input of a chat question through the shared
/// [TranscriptionService] (offline live dictation).
@injectable
class DictationCubit extends Cubit<DictationState> {
  DictationCubit(this._transcriptionService) : super(const DictationIdle());

  static const modelMissingMessage =
      'Le modèle de dictée n’est pas installé. '
      'Lancez une dictée depuis le bouton Semer pour le télécharger.';

  static const dictationFailedMessage =
      'La dictée a échoué. Vérifiez l’accès au microphone.';

  final TranscriptionService _transcriptionService;
  StreamSubscription<DictationSegment>? _subscription;
  String _committed = '';
  String _partial = '';

  String get _transcript {
    if (_committed.isEmpty) return _partial;
    if (_partial.isEmpty) return _committed;
    return '$_committed $_partial';
  }

  /// Starts microphone dictation, streaming the live transcript.
  Future<void> start() async {
    if (state is DictationRecording || state is DictationTranscribing) return;
    try {
      final ready = await _transcriptionService.isReady();
      if (isClosed) return;
      if (!ready) {
        emit(const DictationError(modelMissingMessage));
        return;
      }
    } on Exception {
      if (!isClosed) emit(const DictationError(dictationFailedMessage));
      return;
    }

    _committed = '';
    _partial = '';
    emit(const DictationRecording(''));
    _subscription = _transcriptionService.startDictation().listen(
      (segment) {
        if (segment.isFinal) {
          _committed = _committed.isEmpty
              ? segment.text
              : '$_committed ${segment.text}';
          _partial = '';
        } else {
          _partial = segment.text;
        }
        if (!isClosed && state is DictationRecording) {
          emit(DictationRecording(_transcript));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _stopEngineQuietly();
        if (!isClosed) emit(const DictationError(dictationFailedMessage));
      },
      onDone: () {
        if (isClosed || state is DictationError) return;
        emit(DictationFinished(_transcript.trim()));
      },
    );
  }

  /// Stops the microphone; the engine finalizes pending segments and
  /// closes the stream, which emits [DictationFinished].
  Future<void> stop() async {
    if (state is! DictationRecording) return;
    emit(DictationTranscribing(_transcript));
    try {
      await _transcriptionService.stopDictation();
    } on Exception {
      if (!isClosed) emit(const DictationError(dictationFailedMessage));
    }
  }

  /// Returns to idle once the transcript or error has been consumed.
  void reset() {
    _committed = '';
    _partial = '';
    if (!isClosed) emit(const DictationIdle());
  }

  /// Releases the microphone without surfacing errors — used on error
  /// paths and disposal, where the engine may already be stopped.
  Future<void> _stopEngineQuietly() async {
    try {
      await _transcriptionService.stopDictation();
    } on Exception {
      // Already stopped or engine gone; nothing to release.
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    // The transcription service is a singleton: leaving the page while
    // recording would otherwise keep the microphone open forever.
    if (state is DictationRecording || state is DictationTranscribing) {
      await _stopEngineQuietly();
    }
    return super.close();
  }
}
