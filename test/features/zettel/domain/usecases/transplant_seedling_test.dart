import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/inbox_repository.dart';
import 'package:second_brain/features/zettel/domain/usecases/create_zettel.dart';
import 'package:second_brain/features/zettel/domain/usecases/transplant_seedling.dart';

class MockCreateZettel extends Mock implements CreateZettel {}

class MockInboxRepository extends Mock implements InboxRepository {}

void main() {
  late MockCreateZettel createZettel;
  late MockInboxRepository inboxRepository;
  late TransplantSeedling useCase;

  final tItem = InboxItem(
    id: '20260716094100',
    type: CaptureType.dictation,
    rawText: 'Première ligne du semis.\nSuite du texte dicté.',
    capturedAt: DateTime(2026, 7, 16, 9, 41),
    title: 'Semis enrichi',
    tags: const ['jardin', 'semis'],
  );
  final tZettel = Zettel(
    id: ZettelId.fromString('20260716095000'),
    title: 'Semis enrichi',
    body: 'Première ligne du semis.\nSuite du texte dicté.',
    createdAt: DateTime(2026, 7, 16, 9, 50),
  );

  setUpAll(() {
    registerFallbackValue(const CreateZettelParams(title: 'x', body: 'x'));
    registerFallbackValue(tItem);
  });

  setUp(() {
    createZettel = MockCreateZettel();
    inboxRepository = MockInboxRepository();
    useCase = TransplantSeedling(createZettel, inboxRepository);
    when(() => inboxRepository.updateItem(any())).thenAnswer(
      (invocation) async =>
          Right(invocation.positionalArguments.first as InboxItem),
    );
  });

  test('creates the zettel from the enriched proposal with capture '
      'provenance and marks the item processed', () async {
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));

    final result = await useCase(TransplantSeedlingParams(item: tItem));

    expect(result, Right<Failure, Zettel>(tZettel));
    verify(
      () => createZettel(
        const CreateZettelParams(
          title: 'Semis enrichi',
          body: 'Première ligne du semis.\nSuite du texte dicté.',
          tags: ['jardin', 'semis'],
          source: 'capture:dictation:20260716094100',
        ),
      ),
    ).called(1);
    final updated =
        verify(() => inboxRepository.updateItem(captureAny())).captured.single
            as InboxItem;
    expect(updated.id, tItem.id);
    expect(updated.status, InboxStatus.processed);
  });

  test('uses the asset file name as provenance ref when the capture '
      'has one', () async {
    final withAsset = InboxItem(
      id: tItem.id,
      type: CaptureType.audio,
      rawText: tItem.rawText,
      capturedAt: tItem.capturedAt,
      assetPath: 'assets/meeting.m4a',
      title: tItem.title,
      tags: tItem.tags,
    );
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));

    await useCase(TransplantSeedlingParams(item: withAsset));

    final params =
        verify(() => createZettel(captureAny())).captured.single
            as CreateZettelParams;
    expect(params.source, 'capture:audio:meeting.m4a');
  });

  test('falls back to the first non-empty line when the item has no '
      'enriched title', () async {
    final legacy = InboxItem(
      id: tItem.id,
      type: CaptureType.clipboard,
      rawText: '# Un titre markdown\ncorps',
      capturedAt: tItem.capturedAt,
    );
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));

    await useCase(TransplantSeedlingParams(item: legacy));

    final params =
        verify(() => createZettel(captureAny())).captured.single
            as CreateZettelParams;
    expect(params.title, 'Un titre markdown');
    expect(params.tags, isEmpty);
  });

  test('the edited title, body and tags override the proposal', () async {
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));

    await useCase(
      TransplantSeedlingParams(
        item: tItem,
        title: '  Titre édité  ',
        body: 'Corps édité.',
        tags: const ['autre'],
      ),
    );

    final params =
        verify(() => createZettel(captureAny())).captured.single
            as CreateZettelParams;
    expect(params.title, 'Titre édité');
    expect(params.body, 'Corps édité.');
    expect(params.tags, ['autre']);
  });

  test('a blank edited title falls back to the proposal instead of '
      'failing', () async {
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));

    await useCase(TransplantSeedlingParams(item: tItem, title: '   '));

    final params =
        verify(() => createZettel(captureAny())).captured.single
            as CreateZettelParams;
    expect(params.title, 'Semis enrichi');
  });

  test('a failed creation returns the failure and never touches the '
      'inbox', () async {
    when(
      () => createZettel(any()),
    ).thenAnswer((_) async => const Left(VaultFailure('disque plein')));

    final result = await useCase(TransplantSeedlingParams(item: tItem));

    expect(result, const Left<Failure, Zettel>(VaultFailure('disque plein')));
    verifyNever(() => inboxRepository.updateItem(any()));
  });

  test('a failed status update stays a success (best effort)', () async {
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));
    when(
      () => inboxRepository.updateItem(any()),
    ).thenAnswer((_) async => const Left(VaultFailure('inbox verrouillée')));

    final result = await useCase(TransplantSeedlingParams(item: tItem));

    expect(result, Right<Failure, Zettel>(tZettel));
  });

  test('an already processed item is not re-marked', () async {
    when(() => createZettel(any())).thenAnswer((_) async => Right(tZettel));

    await useCase(
      TransplantSeedlingParams(
        item: tItem.copyWith(status: InboxStatus.processed),
      ),
    );

    verifyNever(() => inboxRepository.updateItem(any()));
  });
}
