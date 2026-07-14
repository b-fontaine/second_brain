import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:second_brain/features/assistant/presentation/bloc/model_status_cubit.dart';
import 'package:second_brain/features/assistant/presentation/bloc/model_status_state.dart';

class MockAssistantRepository extends Mock implements AssistantRepository {}

void main() {
  late MockAssistantRepository repository;

  setUp(() {
    repository = MockAssistantRepository();
  });

  ModelStatusCubit buildCubit({bool supported = true}) =>
      ModelStatusCubit(repository, isLocalAiSupported: () => supported);

  group('ModelStatusCubit.check', () {
    blocTest<ModelStatusCubit, ModelStatusState>(
      'emits ready when the model is installed',
      setUp: () {
        when(
          () => repository.isReady(),
        ).thenAnswer((_) async => const Right(true));
      },
      build: buildCubit,
      act: (cubit) => cubit.check(),
      expect: () => const [ModelStatusChecking(), ModelStatusReady()],
    );

    blocTest<ModelStatusCubit, ModelStatusState>(
      'emits notInstalled when the model is missing',
      setUp: () {
        when(
          () => repository.isReady(),
        ).thenAnswer((_) async => const Right(false));
      },
      build: buildCubit,
      act: (cubit) => cubit.check(),
      expect: () => const [ModelStatusChecking(), ModelStatusNotInstalled()],
    );

    blocTest<ModelStatusCubit, ModelStatusState>(
      'emits an error with the failure message when the check fails',
      setUp: () {
        when(() => repository.isReady()).thenAnswer(
          (_) async => const Left(AiFailure('Moteur IA indisponible')),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.check(),
      expect: () => const [
        ModelStatusChecking(),
        ModelStatusError('Moteur IA indisponible'),
      ],
    );

    blocTest<ModelStatusCubit, ModelStatusState>(
      'emits unsupported without touching the repository on an '
      'unsupported architecture',
      build: () => buildCubit(supported: false),
      act: (cubit) => cubit.check(),
      expect: () => const [
        ModelStatusUnsupported(ModelStatusCubit.unsupportedMessage),
      ],
      verify: (_) {
        verifyNever(() => repository.isReady());
      },
    );
  });

  group('ModelStatusCubit.download', () {
    blocTest<ModelStatusCubit, ModelStatusState>(
      'emits download progress then ready when installation succeeds',
      setUp: () {
        when(() => repository.installModel()).thenAnswer(
          (_) => Stream.fromIterable(const <Either<Failure, double>>[
            Right(0.25),
            Right(0.6),
            Right(1.0),
          ]),
        );
        when(
          () => repository.isReady(),
        ).thenAnswer((_) async => const Right(true));
      },
      build: buildCubit,
      act: (cubit) => cubit.download(),
      expect: () => const [
        ModelStatusDownloading(0),
        ModelStatusDownloading(0.25),
        ModelStatusDownloading(0.6),
        ModelStatusDownloading(1.0),
        ModelStatusReady(),
      ],
    );

    blocTest<ModelStatusCubit, ModelStatusState>(
      'emits an error and stops when the download fails midway',
      setUp: () {
        when(() => repository.installModel()).thenAnswer(
          (_) => Stream.fromIterable(const <Either<Failure, double>>[
            Right(0.1),
            Left(AiFailure('Téléchargement interrompu')),
          ]),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.download(),
      expect: () => const [
        ModelStatusDownloading(0),
        ModelStatusDownloading(0.1),
        ModelStatusError('Téléchargement interrompu'),
      ],
      verify: (_) {
        verifyNever(() => repository.isReady());
      },
    );

    blocTest<ModelStatusCubit, ModelStatusState>(
      'emits an error when the model is still missing after the download',
      setUp: () {
        when(() => repository.installModel()).thenAnswer(
          (_) =>
              Stream.fromIterable(const <Either<Failure, double>>[Right(1.0)]),
        );
        when(
          () => repository.isReady(),
        ).thenAnswer((_) async => const Right(false));
      },
      build: buildCubit,
      act: (cubit) => cubit.download(),
      expect: () => const [
        ModelStatusDownloading(0),
        ModelStatusDownloading(1.0),
        ModelStatusError(ModelStatusCubit.modelMissingAfterInstallMessage),
      ],
    );
  });
}
