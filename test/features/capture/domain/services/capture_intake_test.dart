import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/services/clock.dart';
import 'package:second_brain/features/assistant/domain/services/local_ai_service.dart';
import 'package:second_brain/features/capture/domain/services/capture_intake.dart';
import 'package:second_brain/features/capture/domain/services/clipboard_service.dart';
import 'package:second_brain/features/capture/domain/usecases/recognize_screenshot.dart';
import 'package:second_brain/features/capture/domain/usecases/transcribe_audio_file.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/repositories/inbox_repository.dart';

class MockRecognizeScreenshot extends Mock implements RecognizeScreenshot {}

class MockTranscribeAudioFile extends Mock implements TranscribeAudioFile {}

class MockLocalAiService extends Mock implements LocalAiService {}

class MockInboxRepository extends Mock implements InboxRepository {}

class _FixedClock implements Clock {
  _FixedClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}

void main() {
  late MockRecognizeScreenshot recognizeScreenshot;
  late MockTranscribeAudioFile transcribeAudioFile;
  late MockLocalAiService localAiService;
  late MockInboxRepository inboxRepository;
  late _FixedClock clock;
  late CaptureIntake intake;

  setUpAll(() {
    registerFallbackValue(const RecognizeScreenshotParams('x'));
    registerFallbackValue(const TranscribeAudioFileParams('x'));
    registerFallbackValue(
      InboxItem(
        id: '20260716120000',
        type: CaptureType.clipboard,
        rawText: 'x',
        capturedAt: DateTime(2026, 7, 16, 12),
      ),
    );
  });

  setUp(() {
    recognizeScreenshot = MockRecognizeScreenshot();
    transcribeAudioFile = MockTranscribeAudioFile();
    localAiService = MockLocalAiService();
    inboxRepository = MockInboxRepository();
    clock = _FixedClock(DateTime(2026, 7, 16, 12, 0, 0));
    intake = CaptureIntake(
      recognizeScreenshot,
      transcribeAudioFile,
      localAiService,
      inboxRepository,
      clock,
    );
    // Offline by default: every analyze falls back unless a test opts in.
    when(() => localAiService.isModelReady()).thenAnswer((_) async => false);
  });

  void aiReadyWith(String response) {
    when(() => localAiService.isModelReady()).thenAnswer((_) async => true);
    when(
      () => localAiService.generate(any(), systemPrompt: any(named: 'systemPrompt')),
    ).thenAnswer((_) async => response);
  }

  group('detectKind', () {
    test('clipboard text is text', () {
      expect(
        intake.detectKind(
          const ClipboardPayload(ClipboardContent(text: 'du texte')),
        ),
        SeedKind.text,
      );
    });

    test('clipboard image is image', () {
      expect(
        intake.detectKind(
          const ClipboardPayload(ClipboardContent(imagePath: '/tmp/clip.png')),
        ),
        SeedKind.image,
      );
    });

    test('clipboard text wins over an image when both are present', () {
      expect(
        intake.detectKind(
          const ClipboardPayload(
            ClipboardContent(text: 'texte', imagePath: '/tmp/clip.png'),
          ),
        ),
        SeedKind.text,
      );
    });

    test('an empty clipboard has no kind', () {
      expect(
        intake.detectKind(const ClipboardPayload(ClipboardContent())),
        isNull,
      );
      expect(
        intake.detectKind(const ClipboardPayload(ClipboardContent(text: '  '))),
        isNull,
      );
    });

    test('files are routed by extension, case-insensitively', () {
      expect(intake.detectKind(const FilePayload('/n/note.md')), SeedKind.text);
      expect(
        intake.detectKind(const FilePayload('/n/note.TXT')),
        SeedKind.text,
      );
      expect(
        intake.detectKind(const FilePayload('/n/photo.png')),
        SeedKind.image,
      );
      expect(
        intake.detectKind(const FilePayload('/n/memo.wav')),
        SeedKind.audio,
      );
    });

    test('an unsupported extension has no kind', () {
      expect(intake.detectKind(const FilePayload('/n/doc.pdf')), isNull);
      expect(intake.detectKind(const FilePayload('/n/sansextension')), isNull);
    });

    test('a text payload is always text', () {
      expect(intake.detectKind(const TextPayload('bonjour')), SeedKind.text);
    });
  });

  group('analyze — clipboard text', () {
    const payload = ClipboardPayload(
      ClipboardContent(text: '# Les notes atomiques\nUne idée par note.\n'),
    );

    test('falls back to the first line as title when the model is absent',
        () async {
      final result = await intake.analyze(payload);

      final draft = result.getOrElse((f) => fail(f.message));
      expect(draft.type, CaptureType.clipboard);
      expect(draft.kind, SeedKind.text);
      expect(draft.text, '# Les notes atomiques\nUne idée par note.');
      expect(draft.title, 'Les notes atomiques');
      expect(draft.tags, isEmpty);
      expect(draft.assetPath, isNull);
      verifyNever(
        () => localAiService.generate(
          any(),
          systemPrompt: any(named: 'systemPrompt'),
        ),
      );
    });

    test('uses the AI proposal when the model answers valid JSON', () async {
      aiReadyWith(
        jsonEncode({
          'title': 'Notes atomiques',
          'tags': ['Zettelkasten', 'méthode', 'zettelkasten', ''],
        }),
      );

      final result = await intake.analyze(payload);

      final draft = result.getOrElse((f) => fail(f.message));
      expect(draft.title, 'Notes atomiques');
      // Lowercased, deduplicated, empties dropped.
      expect(draft.tags, ['zettelkasten', 'méthode']);
    });

    test('tolerates prose around the JSON object', () async {
      aiReadyWith('Voici :\n```json\n{"title":"Titre IA","tags":["a"]}\n```');

      final result = await intake.analyze(payload);

      expect(result.getOrElse((f) => fail(f.message)).title, 'Titre IA');
    });

    test('falls back when the model output is not usable JSON', () async {
      aiReadyWith("D'après vos notes, voici la réponse.");

      final result = await intake.analyze(payload);

      final draft = result.getOrElse((f) => fail(f.message));
      expect(draft.title, 'Les notes atomiques');
      expect(draft.tags, isEmpty);
    });

    test('falls back — never fails — when the model throws', () async {
      when(() => localAiService.isModelReady()).thenAnswer((_) async => true);
      when(
        () => localAiService.generate(
          any(),
          systemPrompt: any(named: 'systemPrompt'),
        ),
      ).thenThrow(const AiException('inférence impossible'));

      final result = await intake.analyze(payload);

      final draft = result.getOrElse((f) => fail(f.message));
      expect(draft.title, 'Les notes atomiques');
      expect(draft.tags, isEmpty);
    });

    test('caps the proposed tags at four', () async {
      aiReadyWith(
        jsonEncode({
          'title': 'Titre',
          'tags': ['a', 'b', 'c', 'd', 'e', 'f'],
        }),
      );

      final result = await intake.analyze(payload);

      expect(result.getOrElse((f) => fail(f.message)).tags, hasLength(4));
    });

    test('an empty clipboard fails with a clear message', () async {
      final result = await intake.analyze(
        const ClipboardPayload(ClipboardContent()),
      );

      expect(
        result,
        const Left<Failure, SeedDraft>(
          ValidationFailure('Le presse-papiers est vide'),
        ),
      );
    });
  });

  group('analyze — image (OCR)', () {
    test('runs OCR on a pasted image and keeps the asset path', () async {
      when(
        () => recognizeScreenshot(any()),
      ).thenAnswer((_) async => const Right('Texte reconnu sur l’image'));

      final result = await intake.analyze(
        const ClipboardPayload(ClipboardContent(imagePath: '/tmp/clip.png')),
      );

      final draft = result.getOrElse((f) => fail(f.message));
      expect(draft.type, CaptureType.clipboard);
      expect(draft.kind, SeedKind.image);
      expect(draft.text, 'Texte reconnu sur l’image');
      expect(draft.assetPath, '/tmp/clip.png');
      verify(
        () => recognizeScreenshot(
          const RecognizeScreenshotParams('/tmp/clip.png'),
        ),
      ).called(1);
    });

    test('a picked image file becomes a screenshot capture', () async {
      when(
        () => recognizeScreenshot(any()),
      ).thenAnswer((_) async => const Right('Contenu OCR'));

      final result = await intake.analyze(const FilePayload('/pics/note.jpg'));

      final draft = result.getOrElse((f) => fail(f.message));
      expect(draft.type, CaptureType.screenshot);
      expect(draft.assetPath, '/pics/note.jpg');
    });

    test('surfaces OCR failures', () async {
      when(() => recognizeScreenshot(any())).thenAnswer(
        (_) async =>
            const Left(OcrFailure("Aucun texte n'a été détecté dans l'image")),
      );

      final result = await intake.analyze(
        const ClipboardPayload(ClipboardContent(imagePath: '/tmp/clip.png')),
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('analyze — audio file', () {
    test('transcribes and keeps the asset path', () async {
      when(
        () => transcribeAudioFile(any()),
      ).thenAnswer((_) async => const Right('bonjour le monde'));

      final result = await intake.analyze(const FilePayload('/audio/memo.wav'));

      final draft = result.getOrElse((f) => fail(f.message));
      expect(draft.type, CaptureType.audio);
      expect(draft.kind, SeedKind.audio);
      expect(draft.text, 'bonjour le monde');
      expect(draft.assetPath, '/audio/memo.wav');
      verify(
        () =>
            transcribeAudioFile(const TranscribeAudioFileParams('/audio/memo.wav')),
      ).called(1);
    });

    test('surfaces transcription failures', () async {
      when(() => transcribeAudioFile(any())).thenAnswer(
        (_) async => const Left(TranscriptionFailure('format non supporté')),
      );

      final result = await intake.analyze(const FilePayload('/audio/memo.mp3'));

      expect(
        result,
        const Left<Failure, SeedDraft>(
          TranscriptionFailure('format non supporté'),
        ),
      );
    });
  });

  group('analyze — text file', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('capture_intake_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('reads a markdown file verbatim as a file capture', () async {
      final file = File(p.join(tempDir.path, 'note.md'))
        ..writeAsStringSync('# Une idée\nLe corps de la note.\n');

      final result = await intake.analyze(FilePayload(file.path));

      final draft = result.getOrElse((f) => fail(f.message));
      expect(draft.type, CaptureType.file);
      expect(draft.kind, SeedKind.text);
      expect(draft.text, '# Une idée\nLe corps de la note.');
      expect(draft.title, 'Une idée');
      expect(draft.assetPath, isNull);
    });

    test('an empty file fails with a clear message', () async {
      final file = File(p.join(tempDir.path, 'vide.txt'))
        ..writeAsStringSync('   \n  ');

      final result = await intake.analyze(FilePayload(file.path));

      expect(
        result,
        const Left<Failure, SeedDraft>(
          ValidationFailure('Aucun texte à semer'),
        ),
      );
    });

    test('a missing file fails without throwing', () async {
      final result = await intake.analyze(
        FilePayload(p.join(tempDir.path, 'absent.md')),
      );

      final failure = result.fold((f) => f, (_) => fail('should fail'));
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('absent.md'));
    });

    test('an unsupported extension fails with the extension named', () async {
      final result = await intake.analyze(const FilePayload('/docs/doc.pdf'));

      final failure = result.fold((f) => f, (_) => fail('should fail'));
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('.pdf'));
    });
  });

  group('sow', () {
    const draft = SeedDraft(
      type: CaptureType.clipboard,
      kind: SeedKind.text,
      text: '  Une capture à semer.  ',
      title: '  Titre proposé  ',
      tags: ['jardin', ' jardin ', 'semis', '  '],
    );

    test('persists one enriched inbox item in a single write', () async {
      when(() => inboxRepository.addItem(any())).thenAnswer(
        (invocation) async =>
            Right(invocation.positionalArguments.single as InboxItem),
      );

      final result = await intake.sow(draft);

      final item = result.getOrElse((f) => fail(f.message));
      expect(item.id, '20260716120000');
      expect(item.type, CaptureType.clipboard);
      expect(item.rawText, 'Une capture à semer.');
      expect(item.title, 'Titre proposé');
      // Trimmed, deduplicated, empties dropped.
      expect(item.tags, ['jardin', 'semis']);
      expect(item.capturedAt, clock.current);
      expect(item.status, InboxStatus.pending);
      verify(() => inboxRepository.addItem(any())).called(1);
    });

    test('a blank title is stored as null (Pépinière falls back)', () async {
      when(() => inboxRepository.addItem(any())).thenAnswer(
        (invocation) async =>
            Right(invocation.positionalArguments.single as InboxItem),
      );

      final result = await intake.sow(draft.copyWith(title: '   '));

      expect(result.getOrElse((f) => fail(f.message)).title, isNull);
    });

    test('an emptied text refuses to sow', () async {
      final result = await intake.sow(draft.copyWith(text: '   '));

      expect(
        result,
        const Left<Failure, InboxItem>(
          ValidationFailure('Aucun texte à semer'),
        ),
      );
      verifyNever(() => inboxRepository.addItem(any()));
    });

    test('propagates vault failures', () async {
      when(
        () => inboxRepository.addItem(any()),
      ).thenAnswer((_) async => const Left(VaultFailure('disque plein')));

      final result = await intake.sow(draft);

      expect(
        result,
        const Left<Failure, InboxItem>(VaultFailure('disque plein')),
      );
    });
  });
}
