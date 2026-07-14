import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/assistant/data/datasources/rag_embeddings_gateway.dart';
import 'package:second_brain/features/assistant/data/datasources/vault_rag_index.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';

class MockZettelRepository extends Mock implements ZettelRepository {}

class MockRagEmbeddingsGateway extends Mock implements RagEmbeddingsGateway {}

Zettel zettel(
  String id,
  String title,
  String body, {
  List<String> tags = const [],
}) {
  return Zettel(
    id: ZettelId.fromString(id),
    title: title,
    body: body,
    createdAt: DateTime(2026, 7, 14),
    tags: tags,
  );
}

void main() {
  late MockZettelRepository zettelRepository;
  late MockRagEmbeddingsGateway gateway;
  late StreamController<VaultChanged> vaultChanges;

  final memoire = zettel(
    '20260101100000',
    'Mémoire de travail',
    'La mémoire de travail ne retient que quelques éléments à la fois. '
        'La mémoire est un système actif.',
  );
  final cognition = zettel(
    '20260102100000',
    'Charge cognitive',
    'La charge cognitive augmente avec le nombre d\'informations. '
        'Réduire la charge améliore l\'apprentissage.',
  );
  final jardin = zettel(
    '20260103100000',
    'Jardinage',
    'Les tomates poussent mieux en plein soleil.',
  );

  setUp(() {
    zettelRepository = MockZettelRepository();
    gateway = MockRagEmbeddingsGateway();
    vaultChanges = StreamController<VaultChanged>.broadcast();

    when(
      () => zettelRepository.watchVault(),
    ).thenAnswer((_) => vaultChanges.stream);
    when(() => gateway.isAvailable()).thenAnswer((_) async => false);
  });

  tearDown(() async {
    await vaultChanges.close();
  });

  VaultRagIndex buildIndex(List<Zettel> zettels) {
    when(
      () => zettelRepository.getAllZettels(),
    ).thenAnswer((_) async => Right(zettels));
    return VaultRagIndex(zettelRepository, gateway);
  }

  group('keyword scoring (fallback without embeddings)', () {
    test('matches accented content with an unaccented query', () async {
      final index = buildIndex([memoire, cognition, jardin]);

      final results = await index.topK('memoire');

      expect(results, hasLength(1));
      expect(results.first.$1, memoire.id);
      expect(results.first.$2, isNotEmpty);
    });

    test(
      'matches unaccented query terms against accented text and vice versa',
      () async {
        final index = buildIndex([memoire, cognition, jardin]);

        final accented = await index.topK('MÉMOIRE');
        final unaccented = await index.topK('memoire');

        expect(accented.map((r) => r.$1), unaccented.map((r) => r.$1));
      },
    );

    test('ranks the zettel with more term occurrences first', () async {
      final many = zettel(
        '20260104100000',
        'Sommeil et mémoire',
        'Le sommeil consolide la mémoire. Sans sommeil, la mémoire flanche. '
            'La mémoire dépend du sommeil profond.',
      );
      final index = buildIndex([cognition, memoire, many]);

      final results = await index.topK('memoire');

      expect(results.first.$1, many.id);
      expect(results[1].$1, memoire.id);
    });

    test('weighs title terms double', () async {
      final inTitle = zettel(
        '20260105100000',
        'Apprentissage espacé',
        'Réviser à intervalles réguliers.',
      );
      final inBody = zettel(
        '20260106100000',
        'Méthode de révision',
        "L'apprentissage se renforce par la répétition.",
      );
      final index = buildIndex([inBody, inTitle]);

      final results = await index.topK('apprentissage');

      expect(results.first.$1, inTitle.id);
    });

    test('limits the number of results to k', () async {
      final index = buildIndex([memoire, cognition, jardin]);

      final results = await index.topK('la', k: 1);

      expect(results.length, lessThanOrEqualTo(1));
    });

    test('returns an empty list when nothing matches', () async {
      final index = buildIndex([memoire, cognition]);

      expect(await index.topK('astrophysique'), isEmpty);
      expect(await index.topK(''), isEmpty);
    });

    test('excerpt contains text surrounding the matched term', () async {
      final index = buildIndex([jardin]);

      final results = await index.topK('tomates');

      expect(results.single.$2, contains('tomates'));
    });
  });

  group('incremental reindexing on watchVault', () {
    test('picks up a newly created zettel after a vault change', () async {
      final index = buildIndex([memoire]);
      expect(await index.topK('tomates'), isEmpty);

      when(
        () => zettelRepository.getAllZettels(),
      ).thenAnswer((_) async => Right([memoire, jardin]));
      vaultChanges.add(const VaultChanged());
      await pumpEventQueue();

      final results = await index.topK('tomates');
      expect(results.map((r) => r.$1), contains(jardin.id));
    });

    test('evicts a deleted zettel after a vault change', () async {
      final index = buildIndex([memoire, jardin]);
      expect(await index.topK('tomates'), isNotEmpty);

      when(
        () => zettelRepository.getAllZettels(),
      ).thenAnswer((_) async => Right([memoire]));
      vaultChanges.add(const VaultChanged());
      await pumpEventQueue();

      expect(await index.topK('tomates'), isEmpty);
    });

    test('keeps the previous index when reading the vault fails', () async {
      final index = buildIndex([memoire]);
      expect(await index.topK('memoire'), isNotEmpty);

      when(() => zettelRepository.getAllZettels()).thenAnswer(
        (_) async => const Left(VaultFailure('disque indisponible')),
      );
      vaultChanges.add(const VaultChanged());
      await pumpEventQueue();

      expect(await index.topK('memoire'), isNotEmpty);
    });
  });

  group('embeddings path', () {
    test(
      'uses semantic search results when the gateway is available',
      () async {
        when(() => gateway.isAvailable()).thenAnswer((_) async => true);
        when(
          () => gateway.upsertDocument(
            id: any(named: 'id'),
            content: any(named: 'content'),
          ),
        ).thenAnswer((_) async {});
        when(() => gateway.search(any(), any())).thenAnswer(
          (_) async => [
            (
              id: jardin.id.value,
              content: 'Les tomates poussent mieux en plein soleil.',
              similarity: 0.92,
            ),
          ],
        );
        final index = buildIndex([memoire, jardin]);

        final results = await index.topK('cultiver des légumes', k: 2);

        expect(results, hasLength(1));
        expect(results.single.$1, jardin.id);
        verify(() => gateway.search('cultiver des légumes', 2)).called(1);
      },
    );

    test('falls back to keyword scoring when semantic search throws', () async {
      when(() => gateway.isAvailable()).thenAnswer((_) async => true);
      when(
        () => gateway.upsertDocument(
          id: any(named: 'id'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => gateway.search(any(), any()),
      ).thenThrow(Exception('vector store corrompu'));
      final index = buildIndex([memoire, jardin]);

      final results = await index.topK('tomates');

      expect(results.map((r) => r.$1), contains(jardin.id));
    });

    test('a deleted zettel clears the vector store and re-embeds the '
        'remaining corpus', () async {
      when(() => gateway.isAvailable()).thenAnswer((_) async => true);
      when(
        () => gateway.upsertDocument(
          id: any(named: 'id'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async {});
      when(() => gateway.clear()).thenAnswer((_) async {});
      final index = buildIndex([memoire, jardin]);
      await index.rebuild();
      verifyNever(() => gateway.clear());

      when(
        () => zettelRepository.getAllZettels(),
      ).thenAnswer((_) async => Right([jardin]));
      vaultChanges.add(const VaultChanged());
      await pumpEventQueue();

      verify(() => gateway.clear()).called(1);
      // Initial build + re-embed after the deletion cleared the store.
      verify(
        () => gateway.upsertDocument(
          id: jardin.id.value,
          content: any(named: 'content'),
        ),
      ).called(2);
    });

    test('zettels indexed before the embedder was installed are embedded '
        'once it becomes available', () async {
      when(
        () => gateway.upsertDocument(
          id: any(named: 'id'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async {});
      // First pass without an embedder: keyword index only.
      final index = buildIndex([memoire, jardin]);
      await index.rebuild();
      verifyNever(
        () => gateway.upsertDocument(
          id: any(named: 'id'),
          content: any(named: 'content'),
        ),
      );

      // The embedder gets installed: the whole corpus must be embedded
      // even though no zettel content changed since the last pass.
      when(() => gateway.isAvailable()).thenAnswer((_) async => true);
      vaultChanges.add(const VaultChanged());
      await pumpEventQueue();

      verify(
        () => gateway.upsertDocument(
          id: memoire.id.value,
          content: any(named: 'content'),
        ),
      ).called(1);
      verify(
        () => gateway.upsertDocument(
          id: jardin.id.value,
          content: any(named: 'content'),
        ),
      ).called(1);
    });

    test(
      'ignores stale semantic hits for zettels no longer in the vault',
      () async {
        when(() => gateway.isAvailable()).thenAnswer((_) async => true);
        when(
          () => gateway.upsertDocument(
            id: any(named: 'id'),
            content: any(named: 'content'),
          ),
        ).thenAnswer((_) async {});
        when(() => gateway.search(any(), any())).thenAnswer(
          (_) async => [
            (id: '20991231235959', content: 'note supprimée', similarity: 0.9),
            (id: jardin.id.value, content: jardin.body, similarity: 0.8),
          ],
        );
        final index = buildIndex([jardin]);

        final results = await index.topK('tomates');

        expect(results.map((r) => r.$1), [jardin.id]);
      },
    );
  });
}
