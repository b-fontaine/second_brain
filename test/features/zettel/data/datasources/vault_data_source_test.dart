import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/features/zettel/data/datasources/vault_data_source.dart';
import 'package:second_brain/features/zettel/data/models/zettel_model.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';

import '../fakes.dart';

void main() {
  late Directory tempDir;
  late FakeVaultLocator locator;
  late FileVaultDataSource dataSource;

  Zettel buildZettel({
    String id = '20260714103000',
    String title = 'Mémoire de travail',
    String body = 'Corps de la note.',
    List<String> tags = const ['cognition'],
  }) {
    return Zettel(
      id: ZettelId.fromString(id),
      title: title,
      body: body,
      createdAt: DateTime(2026, 7, 14, 10, 30),
      tags: tags,
    );
  }

  InboxItem buildInboxItem({String id = '20260714110000'}) {
    return InboxItem(
      id: id,
      type: CaptureType.clipboard,
      rawText: 'Texte capturé',
      capturedAt: DateTime(2026, 7, 14, 11, 0),
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('second_brain_vault_');
    locator = FakeVaultLocator(tempDir.path);
    dataSource = FileVaultDataSource(locator);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('unconfigured vault', () {
    test('throws VaultException when no vault path is set', () async {
      final unconfigured = FileVaultDataSource(FakeVaultLocator(null));
      await expectLater(
        unconfigured.readAllZettels(),
        throwsA(isA<VaultException>()),
      );
    });
  });

  group('writeZettel', () {
    test('creates zettel/ on demand with the slugged file name', () async {
      await dataSource.writeZettel(buildZettel());

      final file = File(
        p.join(tempDir.path, 'zettel', '20260714103000-memoire-de-travail.md'),
      );
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), contains('id: "20260714103000"'));
    });

    test('renames the file when the title changed', () async {
      await dataSource.writeZettel(buildZettel());
      await dataSource.writeZettel(buildZettel(title: 'Attention sélective'));

      final zettelDir = Directory(p.join(tempDir.path, 'zettel'));
      final names = (await zettelDir.list().toList())
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .toList();
      expect(names, ['20260714103000-attention-selective.md']);
    });

    test('overwrites in place when the title is unchanged', () async {
      await dataSource.writeZettel(buildZettel());
      await dataSource.writeZettel(buildZettel(body: 'Corps mis à jour.'));

      final read = await dataSource.readZettelById(
        ZettelId.fromString('20260714103000'),
      );
      expect(read?.body, 'Corps mis à jour.');
    });

    test('deletes nothing when several files share the same id: another '
        'device\'s note must never be destroyed by a local write', () async {
      // Two devices created different notes within the same second; after
      // the git merge both files coexist with the same id.
      await dataSource.writeZettel(buildZettel());
      final colliding = File(
        p.join(tempDir.path, 'zettel', '20260714103000-autre-note.md'),
      );
      await colliding.writeAsString(
        ZettelModel.toMarkdown(
          buildZettel(
            title: 'Autre note',
            body: 'Créée sur un autre appareil.',
          ),
        ),
      );

      await dataSource.writeZettel(buildZettel(body: 'Corps mis à jour.'));

      // Old behavior: 'previous' was the first path-sorted match
      // (autre-note.md) and was deleted. Both files must survive.
      expect(await colliding.exists(), isTrue);
      final own = File(
        p.join(tempDir.path, 'zettel', '20260714103000-memoire-de-travail.md'),
      );
      expect(await own.exists(), isTrue);
      expect(await own.readAsString(), contains('Corps mis à jour.'));
    });
  });

  group('readAllZettels', () {
    test('round-trips written zettels', () async {
      final zettel = buildZettel();
      await dataSource.writeZettel(zettel);

      final all = await dataSource.readAllZettels();

      expect(all, hasLength(1));
      expect(all.single, zettel);
    });

    test('skips corrupt and foreign files without crashing', () async {
      await dataSource.writeZettel(buildZettel());
      final zettelDir = Directory(p.join(tempDir.path, 'zettel'));
      await File(
        p.join(zettelDir.path, '20260714103001-broken.md'),
      ).writeAsString('pas de frontmatter du tout');
      await File(
        p.join(zettelDir.path, '20260714103002-bad-yaml.md'),
      ).writeAsString('---\nid: [oops\n---\ncorps\n');
      await File(
        p.join(zettelDir.path, 'README.md'),
      ).writeAsString('# Pas un zettel');
      await File(
        p.join(zettelDir.path, 'notes.txt'),
      ).writeAsString('fichier étranger');

      final all = await dataSource.readAllZettels();

      expect(all, hasLength(1));
      expect(all.single.id.value, '20260714103000');
    });

    test('returns an empty list for a fresh vault', () async {
      expect(await dataSource.readAllZettels(), isEmpty);
    });
  });

  group('readZettelById / zettelExists / deleteZettel', () {
    test('readZettelById returns null when missing', () async {
      expect(
        await dataSource.readZettelById(ZettelId.fromString('20990101000000')),
        isNull,
      );
    });

    test('finds a zettel by id regardless of the slug', () async {
      await dataSource.writeZettel(buildZettel());
      final read = await dataSource.readZettelById(
        ZettelId.fromString('20260714103000'),
      );
      expect(read?.title, 'Mémoire de travail');
    });

    test('zettelExists reflects the file system', () async {
      final id = ZettelId.fromString('20260714103000');
      expect(await dataSource.zettelExists(id), isFalse);
      await dataSource.writeZettel(buildZettel());
      expect(await dataSource.zettelExists(id), isTrue);
    });

    test('deleteZettel removes the file and reports absence', () async {
      final id = ZettelId.fromString('20260714103000');
      await dataSource.writeZettel(buildZettel());

      expect(await dataSource.deleteZettel(id), isTrue);
      expect(await dataSource.zettelExists(id), isFalse);
      expect(await dataSource.deleteZettel(id), isFalse);
    });
  });

  group('inbox items', () {
    test('writes <id>.json into inbox/', () async {
      await dataSource.writeInboxItem(buildInboxItem());
      final file = File(p.join(tempDir.path, 'inbox', '20260714110000.json'));
      expect(await file.exists(), isTrue);
    });

    test('round-trips inbox items', () async {
      final item = buildInboxItem();
      await dataSource.writeInboxItem(item);

      final items = await dataSource.readInboxItems();

      expect(items, hasLength(1));
      expect(items.single, item);
    });

    test('skips corrupt json files without crashing', () async {
      await dataSource.writeInboxItem(buildInboxItem());
      final inboxDir = Directory(p.join(tempDir.path, 'inbox'));
      await File(
        p.join(inboxDir.path, 'broken.json'),
      ).writeAsString('{pas du json');
      await File(
        p.join(inboxDir.path, 'wrong-shape.json'),
      ).writeAsString('[1, 2]');

      final items = await dataSource.readInboxItems();

      expect(items, hasLength(1));
    });

    test('deleteInboxItem removes the file and reports absence', () async {
      await dataSource.writeInboxItem(buildInboxItem());
      expect(await dataSource.deleteInboxItem('20260714110000'), isTrue);
      expect(await dataSource.deleteInboxItem('20260714110000'), isFalse);
    });
  });

  group('assets', () {
    test('ensureAssetsDirectory creates assets/ on demand', () async {
      final path = await dataSource.ensureAssetsDirectory();
      expect(path, p.join(tempDir.path, 'assets'));
      expect(await Directory(path).exists(), isTrue);
    });
  });

  group('vault format', () {
    test('written files stay canonical after a read/write cycle', () async {
      final zettel = buildZettel(
        body: 'Corps.\n\n## Références\n- source externe',
      );
      await dataSource.writeZettel(zettel);
      final read = await dataSource.readZettelById(zettel.id);
      await dataSource.writeZettel(read!);

      final file = File(
        p.join(tempDir.path, 'zettel', '20260714103000-memoire-de-travail.md'),
      );
      expect(await file.readAsString(), ZettelModel.toMarkdown(zettel));
    });
  });
}
