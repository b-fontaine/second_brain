import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/assistant/presentation/bloc/sow_synthesis_cubit.dart';
import 'package:second_brain/features/assistant/presentation/bloc/sow_synthesis_state.dart';
import 'package:second_brain/features/capture/domain/services/capture_intake.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';

class MockCaptureIntake extends Mock implements CaptureIntake {}

void main() {
  late MockCaptureIntake intake;

  const synthesis = 'La mémoire de travail est limitée [[20260101120000]].';
  const tDraft = SeedDraft(
    type: CaptureType.assistant,
    kind: SeedKind.text,
    text: synthesis,
    title: 'Mémoire de travail',
    tags: ['mémoire'],
  );
  final tItem = InboxItem(
    id: '20260716120000',
    type: CaptureType.assistant,
    rawText: synthesis,
    capturedAt: DateTime(2026, 7, 16, 12),
    title: 'Mémoire de travail',
  );

  setUpAll(() {
    registerFallbackValue(const TextPayload('x'));
    registerFallbackValue(tDraft);
  });

  setUp(() {
    intake = MockCaptureIntake();
  });

  SowSynthesisCubit buildCubit() => SowSynthesisCubit(intake);

  test('initial state is idle', () {
    expect(buildCubit().state, const SowSynthesisIdle());
  });

  blocTest<SowSynthesisCubit, SowSynthesisState>(
    'sows the answer through the regular intake with the assistant '
    'provenance',
    setUp: () {
      when(
        () => intake.analyze(any()),
      ).thenAnswer((_) async => const Right(tDraft));
      when(() => intake.sow(any())).thenAnswer((_) async => Right(tItem));
    },
    build: buildCubit,
    act: (cubit) => cubit.sow(synthesis),
    expect: () => const [SowSynthesisSowing(), SowSynthesisSown()],
    verify: (_) {
      final payload =
          verify(() => intake.analyze(captureAny())).captured.single
              as TextPayload;
      expect(payload.text, synthesis);
      expect(payload.source, CaptureType.assistant);
      verify(() => intake.sow(tDraft)).called(1);
    },
  );

  blocTest<SowSynthesisCubit, SowSynthesisState>(
    'surfaces an analyze failure and never writes to the inbox',
    setUp: () {
      when(() => intake.analyze(any())).thenAnswer(
        (_) async => const Left(ValidationFailure('Aucun texte à semer')),
      );
    },
    build: buildCubit,
    act: (cubit) => cubit.sow(synthesis),
    expect: () => const [
      SowSynthesisSowing(),
      SowSynthesisFailure('Aucun texte à semer'),
    ],
    verify: (_) {
      verifyNever(() => intake.sow(any()));
    },
  );

  blocTest<SowSynthesisCubit, SowSynthesisState>(
    'surfaces a sow failure',
    setUp: () {
      when(
        () => intake.analyze(any()),
      ).thenAnswer((_) async => const Right(tDraft));
      when(
        () => intake.sow(any()),
      ).thenAnswer((_) async => const Left(VaultFailure('inbox inaccessible')));
    },
    build: buildCubit,
    act: (cubit) => cubit.sow(synthesis),
    expect: () => const [
      SowSynthesisSowing(),
      SowSynthesisFailure('inbox inaccessible'),
    ],
  );

  blocTest<SowSynthesisCubit, SowSynthesisState>(
    'ignores a second tap while a seeding is in flight',
    setUp: () {
      when(
        () => intake.analyze(any()),
      ).thenAnswer((_) async => const Right(tDraft));
      when(() => intake.sow(any())).thenAnswer((_) async => Right(tItem));
    },
    build: buildCubit,
    act: (cubit) async {
      final first = cubit.sow(synthesis);
      final second = cubit.sow(synthesis);
      await Future.wait([first, second]);
    },
    expect: () => const [SowSynthesisSowing(), SowSynthesisSown()],
    verify: (_) {
      verify(() => intake.analyze(any())).called(1);
    },
  );

  blocTest<SowSynthesisCubit, SowSynthesisState>(
    'reset returns to idle once the outcome has been consumed',
    build: buildCubit,
    seed: () => const SowSynthesisSown(),
    act: (cubit) => cubit.reset(),
    expect: () => const [SowSynthesisIdle()],
  );
}
