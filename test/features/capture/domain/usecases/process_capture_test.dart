import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/services/clock.dart';
import 'package:second_brain/features/assistant/domain/entities/zettel_draft.dart';
import 'package:second_brain/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:second_brain/features/capture/domain/usecases/process_capture.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/repositories/inbox_repository.dart';

class MockInboxRepository extends Mock implements InboxRepository {}

class MockAssistantRepository extends Mock implements AssistantRepository {}

class MockClock extends Mock implements Clock {}

void main() {
  late MockInboxRepository inboxRepository;
  late MockAssistantRepository assistantRepository;
  late MockClock clock;
  late ProcessCapture useCase;

  final tNow = DateTime(2026, 7, 14, 10, 30);
  const tId = '20260714103000';
  const tDraft = ZettelDraft(
    title: 'Mémoire de travail',
    body: 'La mémoire de travail est limitée.',
    tags: ['cognition'],
    sourceInboxItemId: tId,
  );

  setUpAll(() {
    registerFallbackValue(
      InboxItem(
        id: tId,
        type: CaptureType.clipboard,
        rawText: 'x',
        capturedAt: tNow,
      ),
    );
  });

  setUp(() {
    inboxRepository = MockInboxRepository();
    assistantRepository = MockAssistantRepository();
    clock = MockClock();
    useCase = ProcessCapture(inboxRepository, assistantRepository, clock);
    when(() => clock.now()).thenReturn(tNow);
  });

  test('persists the inbox item and returns the proposed drafts', () async {
    when(
      () => assistantRepository.isReady(),
    ).thenAnswer((_) async => const Right(true));
    when(() => inboxRepository.addItem(any())).thenAnswer(
      (invocation) async =>
          Right(invocation.positionalArguments.first as InboxItem),
    );
    when(
      () => assistantRepository.proposeDrafts(
        rawText: any(named: 'rawText'),
        sourceInboxItemId: any(named: 'sourceInboxItemId'),
      ),
    ).thenAnswer((_) async => const Right([tDraft]));

    final result = await useCase(
      const ProcessCaptureParams(
        rawText: '  Une capture audio.  ',
        type: CaptureType.audio,
        assetPath: 'assets/meeting.wav',
      ),
    );

    final outcome = result.getOrElse((f) => throw StateError('$f'));
    expect(outcome.drafts, const [tDraft]);
    expect(outcome.assistantMessage, isNull);
    expect(outcome.item.id, tId);
    expect(outcome.item.type, CaptureType.audio);
    expect(outcome.item.rawText, 'Une capture audio.');
    expect(outcome.item.assetPath, 'assets/meeting.wav');
    expect(outcome.item.capturedAt, tNow);

    final saved =
        verify(() => inboxRepository.addItem(captureAny())).captured.single
            as InboxItem;
    expect(saved.id, tId);
    verify(
      () => assistantRepository.proposeDrafts(
        rawText: 'Une capture audio.',
        sourceInboxItemId: tId,
      ),
    ).called(1);
  });

  test('inbox-only mode never touches the assistant', () async {
    when(() => inboxRepository.addItem(any())).thenAnswer(
      (invocation) async =>
          Right(invocation.positionalArguments.first as InboxItem),
    );

    final result = await useCase(
      const ProcessCaptureParams(
        rawText: 'Texte brut',
        type: CaptureType.clipboard,
        proposeDrafts: false,
      ),
    );

    final outcome = result.getOrElse((f) => throw StateError('$f'));
    expect(outcome.drafts, isEmpty);
    expect(outcome.assistantMessage, isNull);
    verifyNever(() => assistantRepository.isReady());
    verifyNever(
      () => assistantRepository.proposeDrafts(
        rawText: any(named: 'rawText'),
        sourceInboxItemId: any(named: 'sourceInboxItemId'),
      ),
    );
  });

  test(
    'fails with AiFailure without writing when the model is missing',
    () async {
      when(
        () => assistantRepository.isReady(),
      ).thenAnswer((_) async => const Right(false));

      final result = await useCase(
        const ProcessCaptureParams(
          rawText: 'Texte',
          type: CaptureType.clipboard,
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<AiFailure>()),
        (_) => fail('expected a failure'),
      );
      verifyNever(() => inboxRepository.addItem(any()));
    },
  );

  test('propagates the inbox failure', () async {
    when(
      () => assistantRepository.isReady(),
    ).thenAnswer((_) async => const Right(true));
    when(
      () => inboxRepository.addItem(any()),
    ).thenAnswer((_) async => const Left(VaultFailure('disque plein')));

    final result = await useCase(
      const ProcessCaptureParams(rawText: 'Texte', type: CaptureType.clipboard),
    );

    expect(
      result,
      const Left<Failure, ProcessCaptureResult>(VaultFailure('disque plein')),
    );
  });

  test(
    'keeps the saved item and reports a message when the assistant fails',
    () async {
      when(
        () => assistantRepository.isReady(),
      ).thenAnswer((_) async => const Right(true));
      when(() => inboxRepository.addItem(any())).thenAnswer(
        (invocation) async =>
            Right(invocation.positionalArguments.first as InboxItem),
      );
      when(
        () => assistantRepository.proposeDrafts(
          rawText: any(named: 'rawText'),
          sourceInboxItemId: any(named: 'sourceInboxItemId'),
        ),
      ).thenAnswer((_) async => const Left(AiFailure('inférence interrompue')));

      final result = await useCase(
        const ProcessCaptureParams(
          rawText: 'Texte',
          type: CaptureType.clipboard,
        ),
      );

      final outcome = result.getOrElse((f) => throw StateError('$f'));
      expect(outcome.drafts, isEmpty);
      expect(outcome.assistantMessage, contains('inférence interrompue'));
      expect(outcome.item.id, tId);
    },
  );

  test('rejects an empty capture', () async {
    final result = await useCase(
      const ProcessCaptureParams(rawText: '   ', type: CaptureType.clipboard),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<ValidationFailure>()),
      (_) => fail('expected a failure'),
    );
    verifyNever(() => inboxRepository.addItem(any()));
  });
}
