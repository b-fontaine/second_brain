import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/capture/domain/services/capture_intake.dart';
import 'package:second_brain/features/capture/domain/services/clipboard_service.dart';
import 'package:second_brain/features/capture/domain/usecases/capture_from_clipboard.dart';
import 'package:second_brain/features/capture/domain/usecases/ensure_stt_model.dart';
import 'package:second_brain/features/capture/presentation/bloc/seed_intake_cubit.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';

class MockCaptureIntake extends Mock implements CaptureIntake {}

class MockCaptureFromClipboard extends Mock implements CaptureFromClipboard {}

class MockEnsureSttModel extends Mock implements EnsureSttModel {}

void main() {
  late MockCaptureIntake intake;
  late MockCaptureFromClipboard captureFromClipboard;
  late MockEnsureSttModel ensureSttModel;

  const tDraft = SeedDraft(
    type: CaptureType.clipboard,
    kind: SeedKind.text,
    text: 'Une capture.',
    title: 'Titre proposé',
    tags: ['jardin', 'semis'],
  );
  final tItem = InboxItem(
    id: '20260716120000',
    type: CaptureType.clipboard,
    rawText: 'Une capture.',
    capturedAt: DateTime(2026, 7, 16, 12),
    title: 'Titre proposé',
    tags: const ['jardin', 'semis'],
  );

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const TextPayload('x'));
    registerFallbackValue(tDraft);
  });

  setUp(() {
    intake = MockCaptureIntake();
    captureFromClipboard = MockCaptureFromClipboard();
    ensureSttModel = MockEnsureSttModel();
  });

  SeedIntakeCubit buildCubit() =>
      SeedIntakeCubit(intake, captureFromClipboard, ensureSttModel);

  test('initial state is analyzing', () {
    expect(buildCubit().state, const SeedIntakeAnalyzing());
  });

  group('start — clipboard', () {
    blocTest<SeedIntakeCubit, SeedIntakeState>(
      'reads the pasteboard then exposes the analyzed draft',
      build: () {
        when(() => captureFromClipboard(any())).thenAnswer(
          (_) async => const Right(ClipboardContent(text: 'Une capture.')),
        );
        when(
          () => intake.analyze(any()),
        ).thenAnswer((_) async => const Right(tDraft));
        return buildCubit();
      },
      act: (cubit) => cubit.start(const ClipboardSeedSource()),
      expect: () => const [SeedIntakeAnalyzing(), SeedIntakeReady(draft: tDraft)],
      verify: (_) {
        final payload =
            verify(() => intake.analyze(captureAny())).captured.single
                as ClipboardPayload;
        expect(payload.content.text, 'Une capture.');
      },
    );

    blocTest<SeedIntakeCubit, SeedIntakeState>(
      'an unreadable pasteboard is a terminal failure',
      build: () {
        when(() => captureFromClipboard(any())).thenAnswer(
          (_) async =>
              const Left(ValidationFailure('Le presse-papiers est vide')),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.start(const ClipboardSeedSource()),
      expect: () => const [SeedIntakeFailed('Le presse-papiers est vide')],
      verify: (_) => verifyNever(() => intake.analyze(any())),
    );

    blocTest<SeedIntakeCubit, SeedIntakeState>(
      'an analysis failure is a terminal failure',
      build: () {
        when(() => captureFromClipboard(any())).thenAnswer(
          (_) async => const Right(ClipboardContent(text: 'Une capture.')),
        );
        when(() => intake.analyze(any())).thenAnswer(
          (_) async => const Left(OcrFailure('moteur indisponible')),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.start(const ClipboardSeedSource()),
      expect: () => const [SeedIntakeAnalyzing(), SeedIntakeFailed('moteur indisponible')],
    );
  });

  group('start — file', () {
    blocTest<SeedIntakeCubit, SeedIntakeState>(
      'analyzes a text file without touching the STT model',
      build: () {
        when(
          () => intake.detectKind(const FilePayload('/notes/idee.md')),
        ).thenReturn(SeedKind.text);
        when(
          () => intake.analyze(any()),
        ).thenAnswer((_) async => const Right(tDraft));
        return buildCubit();
      },
      act: (cubit) => cubit.start(const FileSeedSource('/notes/idee.md')),
      expect: () => const [SeedIntakeAnalyzing(), SeedIntakeReady(draft: tDraft)],
      verify: (_) => verifyNever(() => ensureSttModel(any())),
    );

    blocTest<SeedIntakeCubit, SeedIntakeState>(
      'streams the model download before analyzing an audio file',
      build: () {
        when(
          () => intake.detectKind(const FilePayload('/audio/memo.wav')),
        ).thenReturn(SeedKind.audio);
        when(() => ensureSttModel(any())).thenAnswer(
          (_) => Stream.fromIterable(const [
            Right<Failure, double>(0.4),
            Right<Failure, double>(1.0),
          ]),
        );
        when(
          () => intake.analyze(any()),
        ).thenAnswer((_) async => const Right(tDraft));
        return buildCubit();
      },
      act: (cubit) => cubit.start(const FileSeedSource('/audio/memo.wav')),
      expect: () => const [
        SeedIntakeAnalyzing(modelProgress: 0.4),
        SeedIntakeAnalyzing(),
        SeedIntakeReady(draft: tDraft),
      ],
    );

    blocTest<SeedIntakeCubit, SeedIntakeState>(
      'stops when the model download fails',
      build: () {
        when(
          () => intake.detectKind(const FilePayload('/audio/memo.wav')),
        ).thenReturn(SeedKind.audio);
        when(() => ensureSttModel(any())).thenAnswer(
          (_) => Stream.value(
            const Left(TranscriptionFailure('réseau indisponible')),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.start(const FileSeedSource('/audio/memo.wav')),
      expect: () => const [SeedIntakeFailed('réseau indisponible')],
      verify: (_) => verifyNever(() => intake.analyze(any())),
    );
  });

  group('draft edits', () {
    blocTest<SeedIntakeCubit, SeedIntakeState>(
      'text, title and parcelle removal update the reviewed draft',
      build: buildCubit,
      seed: () => const SeedIntakeReady(draft: tDraft),
      act: (cubit) => cubit
        ..textChanged('Texte édité.')
        ..titleChanged('Titre édité')
        ..tagRemoved('jardin'),
      expect: () => [
        SeedIntakeReady(draft: tDraft.copyWith(text: 'Texte édité.')),
        SeedIntakeReady(
          draft: tDraft.copyWith(text: 'Texte édité.', title: 'Titre édité'),
        ),
        SeedIntakeReady(
          draft: tDraft.copyWith(
            text: 'Texte édité.',
            title: 'Titre édité',
            tags: const ['semis'],
          ),
        ),
      ],
    );

    blocTest<SeedIntakeCubit, SeedIntakeState>(
      'edits are ignored while sowing',
      build: buildCubit,
      seed: () => const SeedIntakeReady(draft: tDraft, sowing: true),
      act: (cubit) => cubit.textChanged('Texte édité.'),
      expect: () => const <SeedIntakeState>[],
    );
  });

  group('sow', () {
    blocTest<SeedIntakeCubit, SeedIntakeState>(
      'sows the edited draft then reports the planted item',
      build: () {
        when(() => intake.sow(any())).thenAnswer((_) async => Right(tItem));
        return buildCubit();
      },
      seed: () => const SeedIntakeReady(draft: tDraft),
      act: (cubit) => cubit.sow(),
      expect: () => [
        const SeedIntakeReady(draft: tDraft, sowing: true),
        SeedIntakeSown(tItem),
      ],
      verify: (_) => verify(() => intake.sow(tDraft)).called(1),
    );

    blocTest<SeedIntakeCubit, SeedIntakeState>(
      'a failed sow keeps the draft editable with an inline error',
      build: () {
        when(
          () => intake.sow(any()),
        ).thenAnswer((_) async => const Left(VaultFailure('disque plein')));
        return buildCubit();
      },
      seed: () => const SeedIntakeReady(draft: tDraft),
      act: (cubit) => cubit.sow(),
      expect: () => const [
        SeedIntakeReady(draft: tDraft, sowing: true),
        SeedIntakeReady(
          draft: tDraft,
          errorMessage:
              'Le semis a échoué (disque plein). Vos modifications '
              'sont conservées : vous pouvez réessayer.',
        ),
      ],
    );

    blocTest<SeedIntakeCubit, SeedIntakeState>(
      'a double sow writes once',
      build: () {
        when(() => intake.sow(any())).thenAnswer((_) async => Right(tItem));
        return buildCubit();
      },
      seed: () => const SeedIntakeReady(draft: tDraft),
      act: (cubit) async {
        final first = cubit.sow();
        await cubit.sow();
        await first;
      },
      verify: (_) => verify(() => intake.sow(any())).called(1),
    );
  });
}
