import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';
import 'package:second_brain/features/capture/domain/usecases/transcribe_audio_file.dart';

class MockTranscriptionService extends Mock implements TranscriptionService {}

void main() {
  late MockTranscriptionService transcription;
  late TranscribeAudioFile useCase;

  setUp(() {
    transcription = MockTranscriptionService();
    useCase = TranscribeAudioFile(transcription);
  });

  test('returns the transcript', () async {
    when(
      () => transcription.transcribeFile('/tmp/note.wav'),
    ).thenAnswer((_) async => 'bonjour à tous');

    final result = await useCase(
      const TranscribeAudioFileParams('/tmp/note.wav'),
    );

    expect(result, const Right<Failure, String>('bonjour à tous'));
  });

  test('maps TranscriptionException to TranscriptionFailure', () async {
    when(
      () => transcription.transcribeFile(any()),
    ).thenThrow(const TranscriptionException('format non supporté'));

    final result = await useCase(
      const TranscribeAudioFileParams('/tmp/note.mp3'),
    );

    expect(
      result,
      const Left<Failure, String>(TranscriptionFailure('format non supporté')),
    );
  });
}
