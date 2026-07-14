import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/features/assistant/presentation/bloc/dictation_cubit.dart';
import 'package:second_brain/features/assistant/presentation/bloc/dictation_state.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';

class MockTranscriptionService extends Mock implements TranscriptionService {}

void main() {
  late MockTranscriptionService service;
  late StreamController<DictationSegment> segments;

  setUp(() {
    service = MockTranscriptionService();
    segments = StreamController<DictationSegment>();
  });

  tearDown(() {
    // close() only completes once a listener drains the stream; tests where
    // startDictation() is never called have no listener, so awaiting here
    // would hang forever. Fire-and-forget is safe in teardown.
    if (!segments.isClosed) segments.close().ignore();
  });

  group('DictationCubit', () {
    blocTest<DictationCubit, DictationState>(
      'streams partial then final segments and finishes with the transcript',
      setUp: () {
        when(() => service.isReady()).thenAnswer((_) async => true);
        when(() => service.startDictation()).thenAnswer((_) => segments.stream);
        when(() => service.stopDictation()).thenAnswer((_) async {});
      },
      build: () => DictationCubit(service),
      act: (cubit) async {
        await cubit.start();
        segments.add(const DictationSegment('bonjour', isFinal: false));
        segments.add(const DictationSegment('bonjour le monde', isFinal: true));
        await Future<void>.delayed(Duration.zero);
        await cubit.stop();
        await segments.close();
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const [
        DictationRecording(''),
        DictationRecording('bonjour'),
        DictationRecording('bonjour le monde'),
        DictationTranscribing('bonjour le monde'),
        DictationFinished('bonjour le monde'),
      ],
    );

    blocTest<DictationCubit, DictationState>(
      'emits a French error when the dictation model is not installed',
      setUp: () {
        when(() => service.isReady()).thenAnswer((_) async => false);
      },
      build: () => DictationCubit(service),
      act: (cubit) => cubit.start(),
      expect: () => const [DictationError(DictationCubit.modelMissingMessage)],
      verify: (_) {
        verifyNever(() => service.startDictation());
      },
    );

    blocTest<DictationCubit, DictationState>(
      'emits a French error when the engine fails mid-dictation',
      setUp: () {
        when(() => service.isReady()).thenAnswer((_) async => true);
        when(() => service.startDictation()).thenAnswer((_) => segments.stream);
        when(() => service.stopDictation()).thenAnswer((_) async {});
      },
      build: () => DictationCubit(service),
      act: (cubit) async {
        await cubit.start();
        segments.addError(Exception('mic lost'));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const [
        DictationRecording(''),
        DictationError(DictationCubit.dictationFailedMessage),
      ],
      verify: (_) {
        verify(() => service.stopDictation()).called(1);
      },
    );

    test(
      'close() during an active recording releases the microphone',
      () async {
        when(() => service.isReady()).thenAnswer((_) async => true);
        when(() => service.startDictation()).thenAnswer((_) => segments.stream);
        when(() => service.stopDictation()).thenAnswer((_) async {});

        final cubit = DictationCubit(service);
        await cubit.start();
        expect(cubit.state, const DictationRecording(''));

        await cubit.close();

        verify(() => service.stopDictation()).called(1);
      },
    );

    test('close() while idle does not touch the engine', () async {
      final cubit = DictationCubit(service);

      await cubit.close();

      verifyNever(() => service.stopDictation());
    });
  });
}
