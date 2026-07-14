import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/zettel/data/datasources/vault_data_source.dart';
import 'package:second_brain/features/zettel/data/models/zettel_model.dart';
import 'package:second_brain/features/zettel/data/repositories/zettel_repository_impl.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';

import '../fakes.dart';

class MockVaultDataSource extends Mock implements VaultDataSource {}

void main() {
  group('with a real vault on disk', () {
    late Directory tempDir;
    late FakeClock clock;
    late ZettelRepositoryImpl repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('second_brain_repo_');
      clock = FakeClock(DateTime(2026, 7, 14, 10, 30, 0));
      repository = ZettelRepositoryImpl(
        FileVaultDataSource(FakeVaultLocator(tempDir.path)),
        clock,
      );
    });

    tearDown(() async {
      await repository.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<Zettel> create({
      String title = 'Mémoire de travail',
      String body = 'Corps de la note.',
      List<String> tags = const [],
      String? source,
    }) async {
      final result = await repository.createZettel(
        title: title,
        body: body,
        tags: tags,
        source: source,
      );
      return result.match(
        (failure) => fail('createZettel failed: $failure'),
        (zettel) => zettel,
      );
    }

    group('createZettel', () {
      test('mints the id from the clock and writes the file', () async {
        final zettel = await create(
          tags: const ['cognition'],
          source: 'capture:clipboard',
        );

        expect(zettel.id.value, '20260714103000');
        expect(zettel.createdAt, DateTime(2026, 7, 14, 10, 30, 0));
        expect(zettel.title, 'Mémoire de travail');
        expect(zettel.tags, ['cognition']);
        expect(zettel.source, 'capture:clipboard');

        final file = File(
          p.join(
            tempDir.path,
            'zettel',
            '20260714103000-memoire-de-travail.md',
          ),
        );
        expect(await file.exists(), isTrue);
      });

      test('bumps the second when two notes are created within the same '
          'second', () async {
        final first = await create(title: 'Première note');
        final second = await create(title: 'Deuxième note');
        final third = await create(title: 'Troisième note');

        expect(first.id.value, '20260714103000');
        expect(second.id.value, '20260714103001');
        expect(third.id.value, '20260714103002');
      });

      test('skips ids already present on disk', () async {
        final occupied = Zettel(
          id: ZettelId.fromString('20260714103000'),
          title: 'Déjà là',
          body: 'Corps.',
          createdAt: DateTime(2026, 7, 14, 10, 30),
        );
        await File(p.join(tempDir.path, 'zettel', '20260714103000-deja-la.md'))
            .create(recursive: true)
            .then((f) => f.writeAsString(ZettelModel.toMarkdown(occupied)));

        final created = await create(title: 'Nouvelle note');

        expect(created.id.value, '20260714103001');
      });
    });

    group('getAllZettels / getZettelById', () {
      test('returns notes most recent first', () async {
        await create(title: 'Ancienne');
        clock.advance(const Duration(minutes: 5));
        await create(title: 'Récente');

        final result = await repository.getAllZettels();

        final titles = result.match(
          (f) => fail('$f'),
          (zettels) => zettels.map((z) => z.title).toList(),
        );
        expect(titles, ['Récente', 'Ancienne']);
      });

      test('getZettelById returns the note or ZettelNotFoundFailure', () async {
        final created = await create();

        final found = await repository.getZettelById(created.id);
        expect(
          found.match((f) => fail('$f'), (z) => z.title),
          'Mémoire de travail',
        );

        final missing = await repository.getZettelById(
          ZettelId.fromString('20990101000000'),
        );
        missing.match(
          (failure) => expect(failure, isA<ZettelNotFoundFailure>()),
          (_) => fail('expected a failure'),
        );
      });
    });

    group('updateZettel', () {
      test('rewrites the file and renames it when the title changed', () async {
        final created = await create();

        final updated = await repository.updateZettel(
          created.copyWith(title: 'Attention sélective', body: 'Nouveau.'),
        );

        expect(
          updated.match((f) => fail('$f'), (z) => z.title),
          'Attention sélective',
        );

        final zettelDir = Directory(p.join(tempDir.path, 'zettel'));
        final names = (await zettelDir.list().toList())
            .whereType<File>()
            .map((f) => p.basename(f.path))
            .toList();
        expect(names, ['20260714103000-attention-selective.md']);

        final reRead = await repository.getZettelById(created.id);
        expect(reRead.match((f) => fail('$f'), (z) => z.body), 'Nouveau.');
      });

      test('fails with ZettelNotFoundFailure for an unknown id', () async {
        final ghost = Zettel(
          id: ZettelId.fromString('20990101000000'),
          title: 'Fantôme',
          body: 'Corps.',
          createdAt: DateTime(2099),
        );

        final result = await repository.updateZettel(ghost);

        result.match(
          (failure) => expect(failure, isA<ZettelNotFoundFailure>()),
          (_) => fail('expected a failure'),
        );
      });
    });

    group('deleteZettel', () {
      test('removes the note from disk and from the index', () async {
        final created = await create();

        final result = await repository.deleteZettel(created.id);
        expect(result.isRight(), isTrue);

        final zettelDir = Directory(p.join(tempDir.path, 'zettel'));
        expect((await zettelDir.list().toList()).whereType<File>(), isEmpty);

        final again = await repository.deleteZettel(created.id);
        again.match(
          (failure) => expect(failure, isA<ZettelNotFoundFailure>()),
          (_) => fail('expected a failure'),
        );
      });
    });

    group('searchZettels', () {
      setUp(() async {
        await create(
          title: 'Mémoire de travail',
          body: 'La boucle phonologique stocke le son.',
          tags: const ['cognition'],
        );
        clock.advance(const Duration(minutes: 1));
        await create(
          title: 'Systeme de fichiers',
          body: 'Notes stockees en markdown.',
          tags: const ['technique'],
        );
      });

      List<String> titles(Either<Failure, List<Zettel>> result) => result.match(
        (failure) => fail('$failure'),
        (zettels) => zettels.map((z) => z.title).toList(),
      );

      test('matches accented content with an unaccented query', () async {
        expect(titles(await repository.searchZettels('memoire')), [
          'Mémoire de travail',
        ]);
      });

      test('matches unaccented content with an accented query', () async {
        expect(titles(await repository.searchZettels('système')), [
          'Systeme de fichiers',
        ]);
      });

      test('is case-insensitive', () async {
        expect(titles(await repository.searchZettels('MÉMOIRE')), [
          'Mémoire de travail',
        ]);
      });

      test('searches the body with multi-token AND semantics', () async {
        expect(titles(await repository.searchZettels('boucle phonologique')), [
          'Mémoire de travail',
        ]);
        expect(
          titles(await repository.searchZettels('boucle markdown')),
          isEmpty,
        );
      });

      test('searches the tags', () async {
        expect(titles(await repository.searchZettels('technique')), [
          'Systeme de fichiers',
        ]);
      });

      test('returns an empty list when nothing matches', () async {
        expect(titles(await repository.searchZettels('introuvable')), isEmpty);
      });
    });

    group('getBacklinks', () {
      test('returns the notes whose body links to the id', () async {
        final target = await create(title: 'Note cible');
        clock.advance(const Duration(minutes: 1));
        final linking = await create(
          title: 'Note source',
          body: 'Cette idée précise [[${target.id.value}|la cible]].',
        );
        clock.advance(const Duration(minutes: 1));
        await create(title: 'Note isolée', body: 'Aucun lien ici.');

        final backlinks = await repository.getBacklinks(target.id);

        final ids = backlinks.match(
          (f) => fail('$f'),
          (zettels) => zettels.map((z) => z.id.value).toList(),
        );
        expect(ids, [linking.id.value]);

        final none = await repository.getBacklinks(linking.id);
        expect(none.match((f) => fail('$f'), (z) => z), isEmpty);
      });
    });

    group('watchVault', () {
      test('emits after create, update and delete', () async {
        final events = <VaultChanged>[];
        final subscription = repository.watchVault().listen(events.add);

        final created = await create();
        await repository.updateZettel(created.copyWith(body: 'Modifié.'));
        await repository.deleteZettel(created.id);
        await pumpEventQueue();

        expect(events, hasLength(3));
        await subscription.cancel();
      });

      test('supports several simultaneous listeners (broadcast)', () async {
        final first = <VaultChanged>[];
        final second = <VaultChanged>[];
        final sub1 = repository.watchVault().listen(first.add);
        final sub2 = repository.watchVault().listen(second.add);

        await create();
        await pumpEventQueue();

        expect(first, hasLength(1));
        expect(second, hasLength(1));
        await sub1.cancel();
        await sub2.cancel();
      });
    });

    group('notifyExternalChange', () {
      test('invalidates the index and emits VaultChanged', () async {
        await create(title: 'Note interne');

        // Simulate a git pull adding a file behind the repository's back.
        final external = Zettel(
          id: ZettelId.fromString('20260714120000'),
          title: 'Note externe',
          body: 'Arrivée par synchronisation.',
          createdAt: DateTime(2026, 7, 14, 12, 0),
        );
        await File(
          p.join(tempDir.path, 'zettel', '20260714120000-note-externe.md'),
        ).writeAsString(ZettelModel.toMarkdown(external));

        // The cached index does not see the external file yet.
        final before = await repository.getAllZettels();
        expect(before.match((f) => fail('$f'), (z) => z.length), 1);

        final events = <VaultChanged>[];
        final subscription = repository.watchVault().listen(events.add);
        repository.notifyExternalChange();
        await pumpEventQueue();

        expect(events, hasLength(1));
        final after = await repository.getAllZettels();
        expect(after.match((f) => fail('$f'), (z) => z.length), 2);
        await subscription.cancel();
      });
    });

    group('robustness', () {
      test('a corrupt file in the vault is ignored, not fatal', () async {
        await create(title: 'Note valide');
        await File(
          p.join(tempDir.path, 'zettel', '20260714999999-broken.md'),
        ).writeAsString('---\nid: [oops\n---\ncorps');
        repository.notifyExternalChange();

        final result = await repository.getAllZettels();

        expect(result.match((f) => fail('$f'), (z) => z.length), 1);
      });
    });
  });

  group('failure mapping (mocked datasource)', () {
    late MockVaultDataSource dataSource;
    late ZettelRepositoryImpl repository;

    setUpAll(() {
      registerFallbackValue(ZettelId.fromString('20000101000000'));
      registerFallbackValue(
        Zettel(
          id: ZettelId.fromString('20000101000000'),
          title: 'fallback',
          body: '',
          createdAt: DateTime(2000),
        ),
      );
    });

    setUp(() {
      dataSource = MockVaultDataSource();
      repository = ZettelRepositoryImpl(
        dataSource,
        FakeClock(DateTime(2026, 7, 14, 10, 30)),
      );
    });

    tearDown(() => repository.dispose());

    test('VaultException becomes VaultFailure on read', () async {
      when(
        () => dataSource.readAllZettels(),
      ).thenThrow(const VaultException('disque illisible'));

      final result = await repository.getAllZettels();

      result.match(
        (failure) => expect(failure, const VaultFailure('disque illisible')),
        (_) => fail('expected a failure'),
      );
    });

    test('VaultException becomes VaultFailure on write', () async {
      when(
        () => dataSource.readAllZettels(),
      ).thenAnswer((_) async => <Zettel>[]);
      when(() => dataSource.zettelExists(any())).thenAnswer((_) async => false);
      when(
        () => dataSource.writeZettel(any()),
      ).thenThrow(const VaultException('disque plein'));

      final result = await repository.createZettel(
        title: 'Titre',
        body: 'Corps',
      );

      result.match(
        (failure) => expect(failure, const VaultFailure('disque plein')),
        (_) => fail('expected a failure'),
      );
    });

    test('the index reloads after a failed load', () async {
      var calls = 0;
      when(() => dataSource.readAllZettels()).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw const VaultException('premier échec');
        return <Zettel>[];
      });

      final first = await repository.getAllZettels();
      expect(first.isLeft(), isTrue);

      final second = await repository.getAllZettels();
      expect(second.isRight(), isTrue);
      expect(calls, 2);
    });

    test('a load in flight when notifyExternalChange fires is never cached: '
        'notes applied by the pull stay visible', () async {
      final prePullRead = Completer<List<Zettel>>();
      final pulledNote = Zettel(
        id: ZettelId.fromString('20260714120000'),
        title: 'Note distante',
        body: 'Arrivée par synchronisation.',
        createdAt: DateTime(2026, 7, 14, 12),
      );
      var calls = 0;
      when(() => dataSource.readAllZettels()).thenAnswer((_) {
        calls++;
        return calls == 1 ? prePullRead.future : Future.value([pulledNote]);
      });

      // Slow initial index load in flight...
      final staleLoad = repository.getAllZettels();
      // ...during which a pull rewrites the vault.
      repository.notifyExternalChange();
      prePullRead.complete(const <Zettel>[]);
      await staleLoad;

      // The pre-pull snapshot must not have been installed as the index:
      // the next read reloads from disk and sees the pulled note.
      final fresh = await repository.getAllZettels();
      expect(
        fresh.match((f) => fail('$f'), (z) => z.single.id.value),
        '20260714120000',
      );
      expect(calls, 2);
    });
  });
}
