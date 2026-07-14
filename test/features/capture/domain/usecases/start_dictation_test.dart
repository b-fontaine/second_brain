import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';
import 'package:second_brain/features/capture/domain/usecases/start_dictation.dart';

class MockTranscriptionService extends Mock implements TranscriptionService {}

void main() {
  late MockTranscriptionService transcription;
  late StartDictation useCase;

  setUp(() {
    transcription = MockTranscriptionService();
    useCase = StartDictation(transcription);
  });

  test('wraps segments in Right', () async {
    when(() => transcription.startDictation()).thenAnswer(
      (_) => Stream.fromIterable(const [
        DictationSegment('bonjour', isFinal: false),
        DictationSegment('bonjour à tous', isFinal: true),
      ]),
    );

    final events = await useCase(const NoParams()).toList();

    expect(events, hasLength(2));
    expect(events.map((e) => e.getOrElse((f) => throw StateError('$f')).text), [
      'bonjour',
      'bonjour à tous',
    ]);
    expect(
      events.map((e) => e.getOrElse((f) => throw StateError('$f')).isFinal),
      [false, true],
    );
  });

  test('maps a microphone permission denial to PermissionFailure', () async {
    when(() => transcription.startDictation()).thenAnswer(
      (_) => Stream.error(const MicrophonePermissionDeniedException()),
    );

    final events = await useCase(const NoParams()).toList();

    expect(events, const [
      Left<Failure, DictationSegment>(
        PermissionFailure("L'accès au microphone a été refusé"),
      ),
    ]);
  });

  test('maps engine errors to TranscriptionFailure', () async {
    when(() => transcription.startDictation()).thenAnswer(
      (_) => Stream.error(const TranscriptionException('moteur indisponible')),
    );

    final events = await useCase(const NoParams()).toList();

    expect(events, const [
      Left<Failure, DictationSegment>(
        TranscriptionFailure('moteur indisponible'),
      ),
    ]);
  });
}
