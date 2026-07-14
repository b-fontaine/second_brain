import 'dart:async';

import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';

import 'fake_transcription_service.dart';

/// [FakeTranscriptionService] variant whose dictation stream stays OPEN so
/// steps can push utterances while the dictation is running ("I speak ...").
///
/// The base fake yields its [scriptedSegments] then closes the stream, which
/// forbids the Gherkin order start → speak → stop. This subclass keeps a
/// live controller: [startDictation] first replays [scriptedSegments], then
/// [emitSegment] delivers live segments until [stopDictation] closes it.
///
/// Installed by the step "I tap the capture button", which reassigns the
/// world's `fakeTranscriptionService` BEFORE the capture page — and thus the
/// `TranscriptionService` lazy singleton — is instantiated (the DI factory
/// closure in `bdd_world.dart` reads the global at instantiation time).
class CaptureLiveFakeTranscriptionService extends FakeTranscriptionService {
  /// Copies the scripting knobs of [previous] so Background steps that
  /// configured the original fake (e.g. "the local transcription engine is
  /// available") keep their effect after the swap.
  CaptureLiveFakeTranscriptionService.from(FakeTranscriptionService previous) {
    ready = previous.ready;
    scriptedTranscript = previous.scriptedTranscript;
    scriptedSegments = previous.scriptedSegments;
  }

  StreamController<DictationSegment>? _controller;

  @override
  Stream<DictationSegment> startDictation() {
    if (!ready) {
      throw const TranscriptionException(
        'Moteur de transcription non installé (fake)',
      );
    }
    dictating = true;
    final controller = StreamController<DictationSegment>();
    scriptedSegments.forEach(controller.add);
    _controller = controller;
    return controller.stream;
  }

  /// Pushes a live segment into the running dictation stream.
  void emitSegment(DictationSegment segment) {
    final controller = _controller;
    if (controller == null || controller.isClosed) {
      throw StateError('emitSegment: no dictation stream is running');
    }
    controller.add(segment);
  }

  /// Completes the live dictation stream (microphone input ended).
  ///
  /// MUST be called (then pumped) BEFORE the UI stop button is tapped: the
  /// bloc awaits its subscription's `cancel()` on the `StartDictation`
  /// async* generator, and a generator suspended on an inner `await for`
  /// never honours cancellation until the inner stream ends — tapping stop
  /// on a still-open stream deadlocks the bloc.
  void endDictationStream() {
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  @override
  Future<void> stopDictation() async {
    dictating = false;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      // Fire-and-forget: the bloc cancels its subscription BEFORE calling
      // stopDictation, so the done event can never be delivered and the
      // close() future would never complete (deadlock under FakeAsync).
      unawaited(controller.close());
    }
  }
}
