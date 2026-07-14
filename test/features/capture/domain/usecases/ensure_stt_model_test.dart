import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';
import 'package:second_brain/features/capture/domain/usecases/ensure_stt_model.dart';

class MockTranscriptionService extends Mock implements TranscriptionService {}

void main() {
  late MockTranscriptionService transcription;
  late EnsureSttModel useCase;

  setUp(() {
    transcription = MockTranscriptionService();
    useCase = EnsureSttModel(transcription);
  });

  test('emits 1.0 immediately when the model is already installed', () async {
    when(() => transcription.isReady()).thenAnswer((_) async => true);

    final events = await useCase(const NoParams()).toList();

    expect(events, const [Right<Failure, double>(1.0)]);
    verifyNever(() => transcription.installModel());
  });

  test('streams the installation progress on first use', () async {
    when(() => transcription.isReady()).thenAnswer((_) async => false);
    when(
      () => transcription.installModel(),
    ).thenAnswer((_) => Stream.fromIterable(const [0.25, 0.9, 1.0]));

    final events = await useCase(const NoParams()).toList();

    expect(events, const [
      Right<Failure, double>(0.25),
      Right<Failure, double>(0.9),
      Right<Failure, double>(1.0),
      Right<Failure, double>(1.0),
    ]);
  });

  test('maps download errors to TranscriptionFailure', () async {
    when(() => transcription.isReady()).thenAnswer((_) async => false);
    when(() => transcription.installModel()).thenAnswer(
      (_) => Stream.error(const TranscriptionException('réseau indisponible')),
    );

    final events = await useCase(const NoParams()).toList();

    expect(events, const [
      Left<Failure, double>(TranscriptionFailure('réseau indisponible')),
    ]);
  });
}
