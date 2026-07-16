import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/assistant/domain/entities/zettel_draft.dart';
import 'package:second_brain/features/capture/domain/services/capture_intake.dart';
import 'package:second_brain/features/capture/domain/services/clipboard_service.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';
import 'package:second_brain/features/capture/domain/usecases/accept_draft.dart';
import 'package:second_brain/features/capture/domain/usecases/capture_from_clipboard.dart';
import 'package:second_brain/features/capture/domain/usecases/ensure_stt_model.dart';
import 'package:second_brain/features/capture/domain/usecases/process_capture.dart';
import 'package:second_brain/features/capture/domain/usecases/recognize_screenshot.dart';
import 'package:second_brain/features/capture/domain/usecases/start_dictation.dart';
import 'package:second_brain/features/capture/domain/usecases/stop_dictation.dart';
import 'package:second_brain/features/capture/domain/usecases/transcribe_audio_file.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:second_brain/features/capture/presentation/bloc/dictation_transcript.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';

class MockCaptureFromClipboard extends Mock implements CaptureFromClipboard {}

class MockTranscribeAudioFile extends Mock implements TranscribeAudioFile {}

class MockRecognizeScreenshot extends Mock implements RecognizeScreenshot {}

class MockProcessCapture extends Mock implements ProcessCapture {}

class MockAcceptDraft extends Mock implements AcceptDraft {}

class MockStartDictation extends Mock implements StartDictation {}

class MockStopDictation extends Mock implements StopDictation {}

class MockEnsureSttModel extends Mock implements EnsureSttModel {}

class MockCaptureIntake extends Mock implements CaptureIntake {}

void main() {
  late MockCaptureFromClipboard captureFromClipboard;
  late MockTranscribeAudioFile transcribeAudioFile;
  late MockRecognizeScreenshot recognizeScreenshot;
  late MockProcessCapture processCapture;
  late MockAcceptDraft acceptDraft;
  late MockStartDictation startDictation;
  late MockStopDictation stopDictation;
  late MockEnsureSttModel ensureSttModel;
  late MockCaptureIntake captureIntake;

  final tItem = InboxItem(
    id: '20260714103000',
    type: CaptureType.clipboard,
    rawText: 'texte capturé',
    capturedAt: DateTime(2026, 7, 14, 10, 30),
  );
  const tDraft = ZettelDraft(
    title: 'Titre proposé',
    body: 'Corps proposé.',
    tags: ['tag'],
    sourceInboxItemId: '20260714103000',
  );
  const tDraft2 = ZettelDraft(
    title: 'Second titre',
    body: 'Second corps.',
    sourceInboxItemId: '20260714103000',
  );
  final tZettel = Zettel(
    id: ZettelId.fromString('20260714104500'),
    title: 'Titre proposé',
    body: 'Corps proposé.',
    createdAt: DateTime(2026, 7, 14, 10, 45),
  );
  // A stopped dictation is analyzed (enriched) then sown by CaptureIntake.
  const tSeedDraft = SeedDraft(
    type: CaptureType.dictation,
    kind: SeedKind.text,
    text: 'bonjour à tous',
    title: 'Bonjour',
    tags: ['parcelle'],
  );
  final tSownItem = InboxItem(
    id: '20260716120000',
    type: CaptureType.dictation,
    rawText: 'bonjour à tous',
    capturedAt: DateTime(2026, 7, 16, 12),
    title: 'Bonjour',
    tags: const ['parcelle'],
  );

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const TranscribeAudioFileParams('x'));
    registerFallbackValue(const RecognizeScreenshotParams('x'));
    registerFallbackValue(
      const ProcessCaptureParams(rawText: 'x', type: CaptureType.clipboard),
    );
    registerFallbackValue(AcceptDraftParams(draft: tDraft, item: tItem));
    registerFallbackValue(const TextPayload('x'));
    registerFallbackValue(tSeedDraft);
  });

  setUp(() {
    captureFromClipboard = MockCaptureFromClipboard();
    transcribeAudioFile = MockTranscribeAudioFile();
    recognizeScreenshot = MockRecognizeScreenshot();
    processCapture = MockProcessCapture();
    acceptDraft = MockAcceptDraft();
    startDictation = MockStartDictation();
    stopDictation = MockStopDictation();
    ensureSttModel = MockEnsureSttModel();
    captureIntake = MockCaptureIntake();
  });

  CaptureBloc buildBloc() => CaptureBloc(
    captureFromClipboard: captureFromClipboard,
    transcribeAudioFile: transcribeAudioFile,
    recognizeScreenshot: recognizeScreenshot,
    processCapture: processCapture,
    acceptDraft: acceptDraft,
    startDictation: startDictation,
    stopDictation: stopDictation,
    ensureSttModel: ensureSttModel,
    captureIntake: captureIntake,
  );

  test('initial state is CaptureIdle', () {
    expect(buildBloc().state, const CaptureIdle());
  });

  group('clipboard', () {
    blocTest<CaptureBloc, CaptureState>(
      'clipboard text goes straight to editable text',
      build: () {
        when(() => captureFromClipboard(any())).thenAnswer(
          (_) async => const Right(ClipboardContent(text: 'texte copié')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CaptureClipboardRequested()),
      expect: () => const [
        CaptureExtracting(CaptureType.clipboard),
        CaptureTextEditing(type: CaptureType.clipboard, text: 'texte copié'),
      ],
    );

    blocTest<CaptureBloc, CaptureState>(
      'clipboard image is routed through OCR',
      build: () {
        when(() => captureFromClipboard(any())).thenAnswer(
          (_) async =>
              const Right(ClipboardContent(imagePath: '/tmp/clip.png')),
        );
        when(
          () => recognizeScreenshot(any()),
        ).thenAnswer((_) async => const Right('texte de l’image'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CaptureClipboardRequested()),
      expect: () => const [
        CaptureExtracting(CaptureType.clipboard),
        CaptureTextEditing(
          type: CaptureType.clipboard,
          text: 'texte de l’image',
          assetPath: '/tmp/clip.png',
        ),
      ],
      verify: (_) {
        verify(
          () => recognizeScreenshot(
            const RecognizeScreenshotParams('/tmp/clip.png'),
          ),
        ).called(1);
      },
    );

    blocTest<CaptureBloc, CaptureState>(
      'empty clipboard surfaces the failure',
      build: () {
        when(() => captureFromClipboard(any())).thenAnswer(
          (_) async =>
              const Left(ValidationFailure('Le presse-papiers est vide')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CaptureClipboardRequested()),
      expect: () => const [
        CaptureExtracting(CaptureType.clipboard),
        CaptureFailed('Le presse-papiers est vide'),
      ],
    );
  });

  group('audio file', () {
    blocTest<CaptureBloc, CaptureState>(
      'downloads the model then transcribes',
      build: () {
        when(() => ensureSttModel(any())).thenAnswer(
          (_) => Stream.fromIterable(const [
            Right<Failure, double>(0.4),
            Right<Failure, double>(1.0),
          ]),
        );
        when(
          () => transcribeAudioFile(any()),
        ).thenAnswer((_) async => const Right('bonjour le monde'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CaptureAudioFilePicked('/tmp/note.wav')),
      expect: () => const [
        CaptureModelInstalling(type: CaptureType.audio, progress: 0.4),
        CaptureExtracting(CaptureType.audio),
        CaptureTextEditing(
          type: CaptureType.audio,
          text: 'bonjour le monde',
          assetPath: '/tmp/note.wav',
        ),
      ],
    );

    blocTest<CaptureBloc, CaptureState>(
      'surfaces transcription failures',
      build: () {
        when(
          () => ensureSttModel(any()),
        ).thenAnswer((_) => Stream.value(const Right(1.0)));
        when(() => transcribeAudioFile(any())).thenAnswer(
          (_) async => const Left(TranscriptionFailure('format non supporté')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CaptureAudioFilePicked('/tmp/note.mp3')),
      expect: () => const [
        CaptureExtracting(CaptureType.audio),
        CaptureFailed('format non supporté'),
      ],
    );

    blocTest<CaptureBloc, CaptureState>(
      'stops when the model download fails',
      build: () {
        when(() => ensureSttModel(any())).thenAnswer(
          (_) => Stream.value(
            const Left(TranscriptionFailure('réseau indisponible')),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CaptureAudioFilePicked('/tmp/note.wav')),
      expect: () => const [CaptureFailed('réseau indisponible')],
      verify: (_) => verifyNever(() => transcribeAudioFile(any())),
    );
  });

  group('screenshot', () {
    blocTest<CaptureBloc, CaptureState>(
      'runs OCR on the picked image',
      build: () {
        when(
          () => recognizeScreenshot(any()),
        ).thenAnswer((_) async => const Right('déjà vu'));
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const CaptureScreenshotPicked('/tmp/capture.png')),
      expect: () => const [
        CaptureExtracting(CaptureType.screenshot),
        CaptureTextEditing(
          type: CaptureType.screenshot,
          text: 'déjà vu',
          assetPath: '/tmp/capture.png',
        ),
      ],
    );

    blocTest<CaptureBloc, CaptureState>(
      'paste image fails clearly when the clipboard has no image',
      build: () {
        when(() => captureFromClipboard(any())).thenAnswer(
          (_) async => const Right(ClipboardContent(text: 'du texte')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CapturePasteImageRequested()),
      expect: () => const [
        CaptureExtracting(CaptureType.screenshot),
        CaptureFailed(
          "Aucune image dans le presse-papiers. Copiez d'abord une "
          "capture d'écran, puis réessayez.",
        ),
      ],
    );
  });

  group('dictation', () {
    blocTest<CaptureBloc, CaptureState>(
      'streams partials then finals and sows the transcript into the '
      'nursery through CaptureIntake',
      build: () {
        when(
          () => ensureSttModel(any()),
        ).thenAnswer((_) => Stream.value(const Right(1.0)));
        when(() => startDictation(any())).thenAnswer(
          (_) => Stream.fromIterable(const [
            Right<Failure, DictationSegment>(
              DictationSegment('bonjour', isFinal: false),
            ),
            Right<Failure, DictationSegment>(
              DictationSegment('bonjour à tous', isFinal: true),
            ),
          ]),
        );
        when(
          () => stopDictation(any()),
        ).thenAnswer((_) async => const Right(unit));
        when(
          () => captureIntake.analyze(any()),
        ).thenAnswer((_) async => const Right(tSeedDraft));
        when(
          () => captureIntake.sow(any()),
        ).thenAnswer((_) async => Right(tSownItem));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const CaptureDictationStarted());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const CaptureDictationStopped());
      },
      expect: () => [
        const CaptureDictationRunning(DictationTranscript()),
        const CaptureDictationRunning(DictationTranscript(partial: 'bonjour')),
        const CaptureDictationRunning(
          DictationTranscript(committed: 'bonjour à tous'),
        ),
        const CaptureSowing(),
        CaptureSown(tSownItem),
      ],
      verify: (_) {
        verify(() => stopDictation(any())).called(1);
        verify(
          () => captureIntake.analyze(
            const TextPayload('bonjour à tous', source: CaptureType.dictation),
          ),
        ).called(1);
        verify(() => captureIntake.sow(tSeedDraft)).called(1);
      },
    );

    blocTest<CaptureBloc, CaptureState>(
      'a failed sow of the stopped transcript surfaces the vault error',
      build: () {
        when(
          () => captureIntake.analyze(any()),
        ).thenAnswer((_) async => const Right(tSeedDraft));
        when(
          () => captureIntake.sow(any()),
        ).thenAnswer((_) async => const Left(VaultFailure('disque plein')));
        return buildBloc();
      },
      seed: () => const CaptureDictationRunning(
        DictationTranscript(committed: 'bonjour à tous'),
      ),
      act: (bloc) => bloc.add(const CaptureDictationStopped()),
      expect: () => const [
        CaptureSowing(),
        CaptureFailed('disque plein'),
      ],
    );

    blocTest<CaptureBloc, CaptureState>(
      'a reset while sowing wins over the late intake result',
      build: () {
        when(() => captureIntake.analyze(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return const Right(tSeedDraft);
        });
        when(
          () => captureIntake.sow(any()),
        ).thenAnswer((_) async => Right(tSownItem));
        return buildBloc();
      },
      seed: () => const CaptureDictationRunning(
        DictationTranscript(committed: 'bonjour à tous'),
      ),
      act: (bloc) async {
        bloc.add(const CaptureDictationStopped());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const CaptureReset());
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => const [CaptureSowing(), CaptureIdle()],
    );

    blocTest<CaptureBloc, CaptureState>(
      'a microphone permission denial ends in an error state',
      build: () {
        when(
          () => ensureSttModel(any()),
        ).thenAnswer((_) => Stream.value(const Right(1.0)));
        when(() => startDictation(any())).thenAnswer(
          (_) => Stream.value(
            const Left(PermissionFailure("L'accès au microphone a été refusé")),
          ),
        );
        when(
          () => stopDictation(any()),
        ).thenAnswer((_) async => const Right(unit));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CaptureDictationStarted()),
      wait: const Duration(milliseconds: 30),
      expect: () => const [
        CaptureDictationRunning(DictationTranscript()),
        CaptureFailed("L'accès au microphone a été refusé"),
      ],
    );

    blocTest<CaptureBloc, CaptureState>(
      'a double-start begins a single dictation session',
      build: () {
        // The model check suspends before any state is emitted: without the
        // synchronous re-entrancy guard both events would pass the
        // state-based guard and start two sessions (mic left running).
        when(() => ensureSttModel(any())).thenAnswer(
          (_) => Stream.fromFuture(
            Future.delayed(
              const Duration(milliseconds: 10),
              () => const Right<Failure, double>(1.0),
            ),
          ),
        );
        when(
          () => startDictation(any()),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => stopDictation(any()),
        ).thenAnswer((_) async => const Right(unit));
        return buildBloc();
      },
      act: (bloc) => bloc
        ..add(const CaptureDictationStarted())
        ..add(const CaptureDictationStarted()),
      wait: const Duration(milliseconds: 60),
      expect: () => const [CaptureDictationRunning(DictationTranscript())],
      verify: (_) => verify(() => startDictation(any())).called(1),
    );

    blocTest<CaptureBloc, CaptureState>(
      'stopping with an empty transcript reports the absence of speech',
      build: () {
        when(
          () => ensureSttModel(any()),
        ).thenAnswer((_) => Stream.value(const Right(1.0)));
        when(
          () => startDictation(any()),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => stopDictation(any()),
        ).thenAnswer((_) async => const Right(unit));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const CaptureDictationStarted());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const CaptureDictationStopped());
      },
      expect: () => const [
        CaptureDictationRunning(DictationTranscript()),
        CaptureFailed("Aucune parole n'a été détectée"),
      ],
    );
  });

  group('organize', () {
    blocTest<CaptureBloc, CaptureState>(
      'persists the capture and shows the proposed drafts',
      build: () {
        when(() => processCapture(any())).thenAnswer(
          (_) async =>
              Right(ProcessCaptureResult(item: tItem, drafts: const [tDraft])),
        );
        return buildBloc();
      },
      seed: () => const CaptureTextEditing(
        type: CaptureType.clipboard,
        text: 'texte capturé',
      ),
      act: (bloc) => bloc.add(const CaptureOrganizeRequested()),
      expect: () => [
        const CaptureOrganizing(
          type: CaptureType.clipboard,
          text: 'texte capturé',
        ),
        CaptureDraftsReview(item: tItem, drafts: const [tDraft]),
      ],
      verify: (_) {
        final params =
            verify(() => processCapture(captureAny())).captured.single
                as ProcessCaptureParams;
        expect(params.rawText, 'texte capturé');
        expect(params.type, CaptureType.clipboard);
        expect(params.proposeDrafts, isTrue);
      },
    );

    blocTest<CaptureBloc, CaptureState>(
      'offers the inbox fallback when the AI model is missing',
      build: () {
        when(() => processCapture(any())).thenAnswer(
          (_) async =>
              const Left(AiFailure("Le modèle d'IA local n'est pas installé")),
        );
        return buildBloc();
      },
      seed: () => const CaptureTextEditing(
        type: CaptureType.dictation,
        text: 'texte dicté',
      ),
      act: (bloc) => bloc.add(const CaptureOrganizeRequested()),
      expect: () => const [
        CaptureOrganizing(type: CaptureType.dictation, text: 'texte dicté'),
        CaptureAssistantUnavailable(
          type: CaptureType.dictation,
          text: 'texte dicté',
          message: "Le modèle d'IA local n'est pas installé",
        ),
      ],
    );

    blocTest<CaptureBloc, CaptureState>(
      'reports success with a message when drafts are empty',
      build: () {
        when(() => processCapture(any())).thenAnswer(
          (_) async => Right(
            ProcessCaptureResult(
              item: tItem,
              assistantMessage: 'Rien à proposer.',
            ),
          ),
        );
        return buildBloc();
      },
      seed: () => const CaptureTextEditing(
        type: CaptureType.clipboard,
        text: 'texte capturé',
      ),
      act: (bloc) => bloc.add(const CaptureOrganizeRequested()),
      expect: () => const [
        CaptureOrganizing(type: CaptureType.clipboard, text: 'texte capturé'),
        CaptureSuccess(message: 'Rien à proposer.'),
      ],
    );
  });

  group('save to inbox', () {
    blocTest<CaptureBloc, CaptureState>(
      'saves without drafts from the assistant-unavailable state',
      build: () {
        when(
          () => processCapture(any()),
        ).thenAnswer((_) async => Right(ProcessCaptureResult(item: tItem)));
        return buildBloc();
      },
      seed: () => const CaptureAssistantUnavailable(
        type: CaptureType.clipboard,
        text: 'texte capturé',
        message: 'modèle absent',
      ),
      act: (bloc) => bloc.add(const CaptureSaveToInboxRequested()),
      expect: () => const [
        CaptureOrganizing(type: CaptureType.clipboard, text: 'texte capturé'),
        CaptureSuccess(message: "Capture enregistrée dans l'inbox."),
      ],
      verify: (_) {
        final params =
            verify(() => processCapture(captureAny())).captured.single
                as ProcessCaptureParams;
        expect(params.proposeDrafts, isFalse);
      },
    );
  });

  group('drafts review', () {
    blocTest<CaptureBloc, CaptureState>(
      'accepting the last draft ends in success',
      build: () {
        when(() => acceptDraft(any())).thenAnswer((_) async => Right(tZettel));
        return buildBloc();
      },
      seed: () => CaptureDraftsReview(item: tItem, drafts: const [tDraft]),
      act: (bloc) => bloc.add(const CaptureDraftAccepted(0)),
      expect: () => [
        CaptureDraftsReview(
          item: tItem,
          drafts: const [tDraft],
          accepting: true,
        ),
        const CaptureSuccess(
          message: '1 note créée dans le vault.',
          createdCount: 1,
        ),
      ],
      verify: (_) {
        final params =
            verify(() => acceptDraft(captureAny())).captured.single
                as AcceptDraftParams;
        expect(params.draft, tDraft);
        expect(params.item, tItem);
      },
    );

    blocTest<CaptureBloc, CaptureState>(
      'accept all creates every draft then reports the count',
      build: () {
        when(() => acceptDraft(any())).thenAnswer((_) async => Right(tZettel));
        return buildBloc();
      },
      seed: () =>
          CaptureDraftsReview(item: tItem, drafts: const [tDraft, tDraft2]),
      act: (bloc) => bloc.add(const CaptureAcceptAllRequested()),
      expect: () => [
        CaptureDraftsReview(
          item: tItem,
          drafts: const [tDraft, tDraft2],
          accepting: true,
        ),
        const CaptureSuccess(
          message: '2 notes créées dans le vault.',
          createdCount: 2,
        ),
      ],
      verify: (_) => verify(() => acceptDraft(any())).called(2),
    );

    blocTest<CaptureBloc, CaptureState>(
      'a failed acceptance keeps the drafts under review with an inline '
      'error instead of a terminal failure',
      build: () {
        when(
          () => acceptDraft(any()),
        ).thenAnswer((_) async => const Left(VaultFailure('disque plein')));
        return buildBloc();
      },
      seed: () => CaptureDraftsReview(item: tItem, drafts: const [tDraft]),
      act: (bloc) => bloc.add(const CaptureDraftAccepted(0)),
      expect: () => [
        CaptureDraftsReview(
          item: tItem,
          drafts: const [tDraft],
          accepting: true,
        ),
        CaptureDraftsReview(
          item: tItem,
          drafts: const [tDraft],
          errorMessage:
              'La création de la note a échoué (disque plein). '
              'Les brouillons restants sont conservés : vous pouvez '
              'réessayer.',
        ),
      ],
    );

    blocTest<CaptureBloc, CaptureState>(
      'a failed accept-all keeps the not-yet-created drafts under review',
      build: () {
        var calls = 0;
        when(() => acceptDraft(any())).thenAnswer((_) async {
          calls++;
          if (calls == 1) return Right(tZettel);
          return const Left(VaultFailure('disque plein'));
        });
        return buildBloc();
      },
      seed: () =>
          CaptureDraftsReview(item: tItem, drafts: const [tDraft, tDraft2]),
      act: (bloc) => bloc.add(const CaptureAcceptAllRequested()),
      expect: () => [
        CaptureDraftsReview(
          item: tItem,
          drafts: const [tDraft, tDraft2],
          accepting: true,
        ),
        CaptureDraftsReview(
          item: tItem.copyWith(status: InboxStatus.processed),
          drafts: const [tDraft2],
          acceptedCount: 1,
          errorMessage:
              'La création de la note a échoué (disque plein). '
              'Les brouillons restants sont conservés : vous pouvez '
              'réessayer.',
        ),
      ],
      verify: (_) => verify(() => acceptDraft(any())).called(2),
    );

    blocTest<CaptureBloc, CaptureState>(
      'editing a draft updates the review state',
      build: buildBloc,
      seed: () => CaptureDraftsReview(item: tItem, drafts: const [tDraft]),
      act: (bloc) => bloc.add(
        CaptureDraftChanged(0, tDraft.copyWith(title: 'Titre édité')),
      ),
      expect: () => [
        CaptureDraftsReview(
          item: tItem,
          drafts: [tDraft.copyWith(title: 'Titre édité')],
        ),
      ],
    );

    blocTest<CaptureBloc, CaptureState>(
      'rejecting keeps the capture in the inbox',
      build: buildBloc,
      seed: () => CaptureDraftsReview(item: tItem, drafts: const [tDraft]),
      act: (bloc) => bloc.add(const CaptureDraftsRejected()),
      expect: () => const [
        CaptureSuccess(
          message:
              'Brouillons rejetés. La capture reste dans l’inbox pour '
              'un traitement ultérieur.',
        ),
      ],
      verify: (_) => verifyNever(() => acceptDraft(any())),
    );
  });

  group('reset', () {
    blocTest<CaptureBloc, CaptureState>(
      'returns to the idle state',
      build: buildBloc,
      seed: () => const CaptureFailed('erreur'),
      act: (bloc) => bloc.add(const CaptureReset()),
      expect: () => const [CaptureIdle()],
    );
  });
}
