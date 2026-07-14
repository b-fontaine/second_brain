import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/assistant/data/datasources/vault_rag_index.dart';
import 'package:second_brain/features/assistant/data/repositories/gemma_assistant_repository.dart';
import 'package:second_brain/features/assistant/domain/services/local_ai_service.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';

class MockLocalAiService extends Mock implements LocalAiService {}

class MockVaultRagIndex extends Mock implements VaultRagIndex {}

class MockZettelRepository extends Mock implements ZettelRepository {}

void main() {
  late MockLocalAiService localAi;
  late MockVaultRagIndex ragIndex;
  late MockZettelRepository zettelRepository;
  late GemmaAssistantRepository repository;

  final idA = ZettelId.fromString('20260101100000');
  final idB = ZettelId.fromString('20260102100000');
  final idC = ZettelId.fromString('20260103100000');

  final zettelA = Zettel(
    id: idA,
    title: 'Mémoire de travail',
    body: 'La mémoire de travail est limitée.',
    createdAt: DateTime(2026, 1, 1),
  );
  final zettelB = Zettel(
    id: idB,
    title: 'Charge cognitive',
    body: 'La charge cognitive augmente avec le nombre d\'informations.',
    createdAt: DateTime(2026, 1, 2),
  );

  setUpAll(() {
    registerFallbackValue(ZettelId.fromString('20260101000000'));
  });

  setUp(() {
    localAi = MockLocalAiService();
    ragIndex = MockVaultRagIndex();
    zettelRepository = MockZettelRepository();
    repository = GemmaAssistantRepository(localAi, ragIndex, zettelRepository);
  });

  void stubGenerate(String response) {
    when(
      () => localAi.generate(any(), systemPrompt: any(named: 'systemPrompt')),
    ).thenAnswer((_) async => response);
  }

  void stubNoLinks() {
    when(
      () => ragIndex.topK(any(), k: any(named: 'k')),
    ).thenAnswer((_) async => const <(ZettelId, String)>[]);
  }

  group('proposeDrafts', () {
    test('splits a clean JSON response into atomic drafts', () async {
      stubGenerate(
        '{"notes":['
        '{"title":"Idée A","body":"Corps A.","tags":["a"]},'
        '{"title":"Idée B","body":"Corps B.","tags":["b","deux"]},'
        '{"title":"Idée C","body":"Corps C.","tags":[]}'
        ']}',
      );
      stubNoLinks();

      final result = await repository.proposeDrafts(
        rawText: 'texte brut capturé',
        sourceInboxItemId: 'inbox-42',
      );

      final drafts = result.getOrElse((_) => fail('expected Right'));
      expect(drafts, hasLength(3));
      expect(drafts[0].title, 'Idée A');
      expect(drafts[0].body, 'Corps A.');
      expect(drafts[0].tags, ['a']);
      expect(drafts[1].tags, ['b', 'deux']);
      expect(drafts[2].title, 'Idée C');
      for (final draft in drafts) {
        expect(draft.sourceInboxItemId, 'inbox-42');
      }
      // A single model call was enough: no retry.
      verify(
        () => localAi.generate(any(), systemPrompt: any(named: 'systemPrompt')),
      ).called(1);
    });

    test('parses JSON wrapped in a markdown fence', () async {
      stubGenerate(
        'Voici :\n```json\n'
        '{"notes":[{"title":"Titre","body":"Corps.","tags":["t"]}]}'
        '\n```',
      );
      stubNoLinks();

      final result = await repository.proposeDrafts(rawText: 'brut');

      final drafts = result.getOrElse((_) => fail('expected Right'));
      expect(drafts, hasLength(1));
      expect(drafts.single.title, 'Titre');
    });

    test('adds suggested links and Voir aussi lines to each draft', () async {
      stubGenerate('{"notes":[{"title":"Idée","body":"Corps.","tags":["x"]}]}');
      when(
        () => ragIndex.topK(any(), k: 3),
      ).thenAnswer((_) async => [(idA, 'extrait A'), (idB, 'extrait B')]);
      when(
        () => zettelRepository.getZettelById(idA),
      ).thenAnswer((_) async => Right(zettelA));
      when(
        () => zettelRepository.getZettelById(idB),
      ).thenAnswer((_) async => Right(zettelB));

      final result = await repository.proposeDrafts(rawText: 'brut');

      final draft = result.getOrElse((_) => fail('expected Right')).single;
      expect(draft.suggestedLinks, [idA, idB]);
      expect(
        draft.body,
        'Corps.\n'
        '\nVoir aussi : [[20260101100000|Mémoire de travail]]'
        '\nVoir aussi : [[20260102100000|Charge cognitive]]',
      );
      // Retrieval query combines title and body.
      verify(() => ragIndex.topK('Idée\nCorps.', k: 3)).called(1);
    });

    test(
      'uses a plain [[id]] link when the target title is unavailable',
      () async {
        stubGenerate('{"notes":[{"title":"Idée","body":"Corps.","tags":[]}]}');
        when(
          () => ragIndex.topK(any(), k: 3),
        ).thenAnswer((_) async => [(idA, 'extrait')]);
        when(
          () => zettelRepository.getZettelById(idA),
        ).thenAnswer((_) async => Left(ZettelNotFoundFailure(idA.value)));

        final result = await repository.proposeDrafts(rawText: 'brut');

        final draft = result.getOrElse((_) => fail('expected Right')).single;
        expect(draft.body, contains('Voir aussi : [[20260101100000]]'));
        expect(draft.body, isNot(contains('|')));
      },
    );

    test('retries once with a correction prompt after invalid JSON', () async {
      var call = 0;
      when(
        () => localAi.generate(any(), systemPrompt: any(named: 'systemPrompt')),
      ).thenAnswer((_) async {
        call++;
        return call == 1
            ? 'désolé, voici les notes : titre / corps'
            : '{"notes":[{"title":"Réparé","body":"Corps.","tags":[]}]}';
      });
      stubNoLinks();

      final result = await repository.proposeDrafts(rawText: 'brut');

      final drafts = result.getOrElse((_) => fail('expected Right'));
      expect(drafts.single.title, 'Réparé');
      final prompts = verify(
        () => localAi.generate(
          captureAny(),
          systemPrompt: any(named: 'systemPrompt'),
        ),
      ).captured;
      expect(prompts, hasLength(2));
      expect(prompts[1], contains('JSON valide'));
      expect(prompts[1], contains('brut'));
    });

    test('falls back to a single raw draft when JSON stays invalid', () async {
      stubGenerate('toujours pas de JSON');
      stubNoLinks();
      const rawText = '# Ma capture importante\ndeuxième ligne de contenu';

      final result = await repository.proposeDrafts(
        rawText: rawText,
        sourceInboxItemId: 'inbox-1',
      );

      final drafts = result.getOrElse((_) => fail('expected Right'));
      expect(drafts, hasLength(1));
      expect(drafts.single.title, 'Ma capture importante');
      expect(drafts.single.body, rawText);
      expect(drafts.single.sourceInboxItemId, 'inbox-1');
      verify(
        () => localAi.generate(any(), systemPrompt: any(named: 'systemPrompt')),
      ).called(2);
    });

    test('maps AiException to AiFailure', () async {
      when(
        () => localAi.generate(any(), systemPrompt: any(named: 'systemPrompt')),
      ).thenThrow(const AiException('modèle indisponible'));

      final result = await repository.proposeDrafts(rawText: 'brut');

      expect(
        result,
        const Left<Failure, dynamic>(AiFailure('modèle indisponible')),
      );
    });
  });

  group('answerQuestion', () {
    test('builds the context from topK and extracts citations', () async {
      when(
        () => ragIndex.topK(any(), k: 5),
      ).thenAnswer((_) async => [(idA, 'extrait A'), (idB, 'extrait B')]);
      when(
        () => zettelRepository.getZettelById(idA),
      ).thenAnswer((_) async => Right(zettelA));
      when(
        () => zettelRepository.getZettelById(idB),
      ).thenAnswer((_) async => Right(zettelB));
      stubGenerate(
        'La mémoire de travail est limitée [[20260101100000]]. '
        'Voir aussi [[20260103100000]].',
      );

      final result = await repository.answerQuestion(
        'Que sait-on de la mémoire ?',
      );

      final answer = result.getOrElse((_) => fail('expected Right'));
      expect(answer.text, contains('[[20260101100000]]'));
      // Cited in the answer first (idA, idC), then remaining context (idB).
      expect(answer.citedZettels, [idA, idC, idB]);

      final prompt =
          verify(
                () => localAi.generate(
                  captureAny(),
                  systemPrompt: any(named: 'systemPrompt'),
                ),
              ).captured.single
              as String;
      expect(prompt, contains('[[20260101100000]] Mémoire de travail'));
      expect(prompt, contains('[[20260102100000]] Charge cognitive'));
      expect(prompt, contains('Question : Que sait-on de la mémoire ?'));
    });

    test('truncates long note bodies in the context (~800 chars)', () async {
      final longZettel = Zettel(
        id: idA,
        title: 'Note très longue',
        body: 'début ${'a' * 850} FIN_UNIQUE',
        createdAt: DateTime(2026, 1, 1),
      );
      when(
        () => ragIndex.topK(any(), k: 5),
      ).thenAnswer((_) async => [(idA, 'extrait')]);
      when(
        () => zettelRepository.getZettelById(idA),
      ).thenAnswer((_) async => Right(longZettel));
      stubGenerate('Réponse.');

      await repository.answerQuestion('question');

      final prompt =
          verify(
                () => localAi.generate(
                  captureAny(),
                  systemPrompt: any(named: 'systemPrompt'),
                ),
              ).captured.single
              as String;
      expect(prompt, isNot(contains('FIN_UNIQUE')));
      expect(prompt, contains('début'));
    });

    test('answers without calling the model when no note matches', () async {
      when(
        () => ragIndex.topK(any(), k: 5),
      ).thenAnswer((_) async => const <(ZettelId, String)>[]);

      final result = await repository.answerQuestion('question inconnue');

      final answer = result.getOrElse((_) => fail('expected Right'));
      expect(answer.text, contains('aucune note pertinente'));
      expect(answer.citedZettels, isEmpty);
      verifyNever(
        () => localAi.generate(any(), systemPrompt: any(named: 'systemPrompt')),
      );
    });

    test('uses the topK excerpt when the zettel cannot be read', () async {
      when(
        () => ragIndex.topK(any(), k: 5),
      ).thenAnswer((_) async => [(idA, 'extrait de secours')]);
      when(
        () => zettelRepository.getZettelById(idA),
      ).thenAnswer((_) async => Left(ZettelNotFoundFailure(idA.value)));
      stubGenerate('Réponse.');

      final result = await repository.answerQuestion('question');

      expect(result.isRight(), isTrue);
      final prompt =
          verify(
                () => localAi.generate(
                  captureAny(),
                  systemPrompt: any(named: 'systemPrompt'),
                ),
              ).captured.single
              as String;
      expect(prompt, contains('extrait de secours'));
    });

    test('maps AiException to AiFailure', () async {
      when(
        () => ragIndex.topK(any(), k: 5),
      ).thenAnswer((_) async => [(idA, 'extrait')]);
      when(
        () => zettelRepository.getZettelById(idA),
      ).thenAnswer((_) async => Right(zettelA));
      when(
        () => localAi.generate(any(), systemPrompt: any(named: 'systemPrompt')),
      ).thenThrow(const AiException('mémoire insuffisante'));

      final result = await repository.answerQuestion('question');

      expect(
        result,
        const Left<Failure, dynamic>(AiFailure('mémoire insuffisante')),
      );
    });
  });

  group('isReady', () {
    test('delegates to LocalAiService', () async {
      when(() => localAi.isModelReady()).thenAnswer((_) async => true);

      expect(await repository.isReady(), const Right<Failure, bool>(true));

      when(() => localAi.isModelReady()).thenAnswer((_) async => false);

      expect(await repository.isReady(), const Right<Failure, bool>(false));
    });

    test('maps AiException to AiFailure', () async {
      when(
        () => localAi.isModelReady(),
      ).thenThrow(const AiException('registre non initialisé'));

      expect(
        await repository.isReady(),
        const Left<Failure, bool>(AiFailure('registre non initialisé')),
      );
    });
  });

  group('installModel', () {
    test('maps download progress to Right(fraction)', () async {
      when(() => localAi.installModel()).thenAnswer(
        (_) => Stream.fromIterable(const [
          ModelDownloadProgress(0.25),
          ModelDownloadProgress(1.0),
        ]),
      );

      final events = await repository.installModel().toList();

      expect(events, const [
        Right<Failure, double>(0.25),
        Right<Failure, double>(1.0),
      ]);
    });

    test('converts a stream error into Left(AiFailure)', () async {
      Stream<ModelDownloadProgress> failing() async* {
        yield const ModelDownloadProgress(0.1);
        throw const AiException('erreur réseau pendant le téléchargement');
      }

      when(() => localAi.installModel()).thenAnswer((_) => failing());

      final events = await repository.installModel().toList();

      expect(events, const [
        Right<Failure, double>(0.1),
        Left<Failure, double>(
          AiFailure('erreur réseau pendant le téléchargement'),
        ),
      ]);
    });
  });
}
