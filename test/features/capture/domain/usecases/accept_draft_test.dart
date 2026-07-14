import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/assistant/domain/entities/zettel_draft.dart';
import 'package:second_brain/features/capture/domain/usecases/accept_draft.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/inbox_repository.dart';
import 'package:second_brain/features/zettel/domain/usecases/create_zettel.dart';

class MockCreateZettel extends Mock implements CreateZettel {}

class MockInboxRepository extends Mock implements InboxRepository {}

void main() {
  late MockCreateZettel createZettel;
  late MockInboxRepository inboxRepository;
  late AcceptDraft useCase;

  final tItem = InboxItem(
    id: '20260714103000',
    type: CaptureType.audio,
    rawText: 'transcript brut',
    capturedAt: DateTime(2026, 7, 14, 10, 30),
    assetPath: 'assets/meeting.m4a',
  );
  const tDraft = ZettelDraft(
    title: 'Mémoire de travail',
    body: 'La mémoire de travail est limitée à quelques éléments.',
    tags: ['cognition', 'memoire'],
    sourceInboxItemId: '20260714103000',
  );
  final tZettel = Zettel(
    id: ZettelId.fromString('20260714104500'),
    title: 'Mémoire de travail',
    body: 'La mémoire de travail est limitée à quelques éléments.',
    createdAt: DateTime(2026, 7, 14, 10, 45),
  );

  setUpAll(() {
    registerFallbackValue(const CreateZettelParams(title: 'x', body: 'x'));
    registerFallbackValue(tItem);
  });

  setUp(() {
    createZettel = MockCreateZettel();
    inboxRepository = MockInboxRepository();
    useCase = AcceptDraft(createZettel, inboxRepository);
  });

  test('creates the zettel with capture provenance and marks the item '
      'processed', () async {
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));
    when(() => inboxRepository.updateItem(any())).thenAnswer(
      (invocation) async =>
          Right(invocation.positionalArguments.first as InboxItem),
    );

    final result = await useCase(AcceptDraftParams(draft: tDraft, item: tItem));

    expect(result, Right<Failure, Zettel>(tZettel));

    final params =
        verify(() => createZettel(captureAny())).captured.single
            as CreateZettelParams;
    expect(params.title, tDraft.title);
    expect(params.body, tDraft.body);
    expect(params.tags, tDraft.tags);
    expect(params.source, 'capture:audio:meeting.m4a');

    final updated =
        verify(() => inboxRepository.updateItem(captureAny())).captured.single
            as InboxItem;
    expect(updated.id, tItem.id);
    expect(updated.status, InboxStatus.processed);
  });

  test('uses the inbox item id as ref when there is no asset', () async {
    final itemWithoutAsset = InboxItem(
      id: '20260714103000',
      type: CaptureType.dictation,
      rawText: 'texte dicté',
      capturedAt: DateTime(2026, 7, 14, 10, 30),
    );
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));
    when(() => inboxRepository.updateItem(any())).thenAnswer(
      (invocation) async =>
          Right(invocation.positionalArguments.first as InboxItem),
    );

    await useCase(AcceptDraftParams(draft: tDraft, item: itemWithoutAsset));

    final params =
        verify(() => createZettel(captureAny())).captured.single
            as CreateZettelParams;
    expect(params.source, 'capture:dictation:20260714103000');
  });

  test('appends missing suggested links to the body', () async {
    final draft = tDraft.copyWith(
      suggestedLinks: [
        ZettelId.fromString('20250101120000'),
        ZettelId.fromString('20250202120000'),
      ],
      body: 'Corps qui cite déjà [[20250101120000|une note]].',
    );
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));
    when(() => inboxRepository.updateItem(any())).thenAnswer(
      (invocation) async =>
          Right(invocation.positionalArguments.first as InboxItem),
    );

    await useCase(AcceptDraftParams(draft: draft, item: tItem));

    final params =
        verify(() => createZettel(captureAny())).captured.single
            as CreateZettelParams;
    expect(
      params.body,
      'Corps qui cite déjà [[20250101120000|une note]].\n\n'
      'Voir aussi : [[20250202120000]]',
    );
  });

  test('propagates the creation failure and leaves the item pending', () async {
    when(
      () => createZettel(any()),
    ).thenAnswer((_) async => const Left(ValidationFailure('titre vide')));

    final result = await useCase(AcceptDraftParams(draft: tDraft, item: tItem));

    expect(
      result,
      const Left<Failure, Zettel>(ValidationFailure('titre vide')),
    );
    verifyNever(() => inboxRepository.updateItem(any()));
  });

  test('still succeeds when marking the item processed fails', () async {
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));
    when(
      () => inboxRepository.updateItem(any()),
    ).thenAnswer((_) async => const Left(VaultFailure('lecture seule')));

    final result = await useCase(AcceptDraftParams(draft: tDraft, item: tItem));

    expect(result, Right<Failure, Zettel>(tZettel));
  });

  test('does not update an item already processed', () async {
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));

    final processed = tItem.copyWith(status: InboxStatus.processed);
    final result = await useCase(
      AcceptDraftParams(draft: tDraft, item: processed),
    );

    expect(result, Right<Failure, Zettel>(tZettel));
    verifyNever(() => inboxRepository.updateItem(any()));
  });
}
