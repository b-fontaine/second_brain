import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';
import 'package:second_brain/features/capture/domain/usecases/ensure_stt_model.dart';
import 'package:second_brain/features/setup/presentation/bloc/models_install_cubit.dart';

class MockTranscriptionService extends Mock implements TranscriptionService {}

class MockEnsureSttModel extends Mock implements EnsureSttModel {}

class MockAssistantRepository extends Mock implements AssistantRepository {}

void main() {
  late MockTranscriptionService transcription;
  late MockEnsureSttModel ensureSttModel;
  late MockAssistantRepository assistantRepository;

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    transcription = MockTranscriptionService();
    ensureSttModel = MockEnsureSttModel();
    assistantRepository = MockAssistantRepository();

    when(() => transcription.isReady()).thenAnswer((_) async => false);
    when(
      () => assistantRepository.isReady(),
    ).thenAnswer((_) async => const Right(false));
  });

  ModelsInstallCubit buildCubit({bool assistantSupported = true}) {
    return ModelsInstallCubit(
      transcription,
      ensureSttModel,
      assistantRepository,
      isAssistantSupported: () => assistantSupported,
    );
  }

  group('init', () {
    blocTest<ModelsInstallCubit, ModelsInstallState>(
      'reports both models as not installed',
      build: buildCubit,
      act: (cubit) => cubit.init(),
      verify: (cubit) {
        expect(cubit.state.voice.phase, ModelInstallPhase.notInstalled);
        expect(cubit.state.assistant.phase, ModelInstallPhase.notInstalled);
      },
    );

    blocTest<ModelsInstallCubit, ModelsInstallState>(
      'reports both models as installed',
      build: buildCubit,
      setUp: () {
        when(() => transcription.isReady()).thenAnswer((_) async => true);
        when(
          () => assistantRepository.isReady(),
        ).thenAnswer((_) async => const Right(true));
      },
      act: (cubit) => cubit.init(),
      verify: (cubit) {
        expect(cubit.state.voice.phase, ModelInstallPhase.ready);
        expect(cubit.state.assistant.phase, ModelInstallPhase.ready);
      },
    );

    blocTest<ModelsInstallCubit, ModelsInstallState>(
      'marks the assistant unsupported on excluded ABIs without touching '
      'the repository',
      build: () => buildCubit(assistantSupported: false),
      act: (cubit) => cubit.init(),
      verify: (cubit) {
        expect(cubit.state.assistant.phase, ModelInstallPhase.unsupported);
        expect(
          cubit.state.assistant.message,
          ModelsInstallCubit.assistantUnsupportedMessage,
        );
        verifyNever(() => assistantRepository.isReady());
      },
    );

    blocTest<ModelsInstallCubit, ModelsInstallState>(
      'surfaces an assistant readiness failure',
      build: buildCubit,
      setUp: () {
        when(
          () => assistantRepository.isReady(),
        ).thenAnswer((_) async => const Left(AiFailure('moteur indisponible')));
      },
      act: (cubit) => cubit.init(),
      verify: (cubit) {
        expect(cubit.state.assistant.phase, ModelInstallPhase.failed);
        expect(cubit.state.assistant.message, 'moteur indisponible');
      },
    );

    blocTest<ModelsInstallCubit, ModelsInstallState>(
      'never clobbers a download in progress on remount',
      build: buildCubit,
      seed: () => const ModelsInstallState(
        voice: ModelInstallInfo.downloading(0.4),
        assistant: ModelInstallInfo.notInstalled(),
      ),
      act: (cubit) => cubit.init(),
      verify: (cubit) {
        expect(cubit.state.voice, const ModelInstallInfo.downloading(0.4));
      },
    );
  });

  group('downloadVoice', () {
    blocTest<ModelsInstallCubit, ModelsInstallState>(
      'streams the merged STT progress then lands on ready',
      build: buildCubit,
      setUp: () {
        when(() => ensureSttModel(any())).thenAnswer(
          (_) => Stream.fromIterable(const [Right(0.5), Right(1.0)]),
        );
      },
      act: (cubit) => cubit.downloadVoice(),
      verify: (cubit) {
        expect(cubit.state.voice.phase, ModelInstallPhase.ready);
      },
      expect: () => [
        isA<ModelsInstallState>().having(
          (s) => s.voice,
          'voice',
          const ModelInstallInfo.downloading(0),
        ),
        isA<ModelsInstallState>().having(
          (s) => s.voice,
          'voice',
          const ModelInstallInfo.downloading(0.5),
        ),
        isA<ModelsInstallState>().having(
          (s) => s.voice,
          'voice',
          const ModelInstallInfo.downloading(1.0),
        ),
        isA<ModelsInstallState>().having(
          (s) => s.voice,
          'voice',
          const ModelInstallInfo.ready(),
        ),
      ],
    );

    blocTest<ModelsInstallCubit, ModelsInstallState>(
      'reports the failure and offers a retry',
      build: buildCubit,
      setUp: () {
        when(() => ensureSttModel(any())).thenAnswer(
          (_) => Stream.fromIterable(const [
            Right(0.2),
            Left(TranscriptionFailure('réseau coupé')),
          ]),
        );
      },
      act: (cubit) => cubit.downloadVoice(),
      verify: (cubit) {
        expect(cubit.state.voice.phase, ModelInstallPhase.failed);
        expect(cubit.state.voice.message, 'réseau coupé');
      },
    );

    blocTest<ModelsInstallCubit, ModelsInstallState>(
      'is a no-op when the model is already installed',
      build: buildCubit,
      seed: () => const ModelsInstallState(
        voice: ModelInstallInfo.ready(),
        assistant: ModelInstallInfo.notInstalled(),
      ),
      act: (cubit) => cubit.downloadVoice(),
      expect: () => const <ModelsInstallState>[],
      verify: (_) {
        verifyNever(() => ensureSttModel(any()));
      },
    );
  });

  group('downloadAssistant', () {
    blocTest<ModelsInstallCubit, ModelsInstallState>(
      'streams the LLM progress then lands on ready',
      build: buildCubit,
      setUp: () {
        when(() => assistantRepository.installModel()).thenAnswer(
          (_) => Stream.fromIterable(const [Right(0.25), Right(1.0)]),
        );
      },
      act: (cubit) => cubit.downloadAssistant(),
      verify: (cubit) {
        expect(cubit.state.assistant.phase, ModelInstallPhase.ready);
      },
    );

    blocTest<ModelsInstallCubit, ModelsInstallState>(
      'reports a download failure with the failure message',
      build: buildCubit,
      setUp: () {
        when(() => assistantRepository.installModel()).thenAnswer(
          (_) => Stream.fromIterable(const [
            Left(AiFailure('téléchargement interrompu')),
          ]),
        );
      },
      act: (cubit) => cubit.downloadAssistant(),
      verify: (cubit) {
        expect(cubit.state.assistant.phase, ModelInstallPhase.failed);
        expect(cubit.state.assistant.message, 'téléchargement interrompu');
      },
    );

    blocTest<ModelsInstallCubit, ModelsInstallState>(
      'never downloads on an unsupported platform',
      build: () => buildCubit(assistantSupported: false),
      seed: () => const ModelsInstallState(
        voice: ModelInstallInfo.notInstalled(),
        assistant: ModelInstallInfo.unsupported(
          ModelsInstallCubit.assistantUnsupportedMessage,
        ),
      ),
      act: (cubit) => cubit.downloadAssistant(),
      expect: () => const <ModelsInstallState>[],
      verify: (_) {
        verifyNever(() => assistantRepository.installModel());
      },
    );
  });
}
