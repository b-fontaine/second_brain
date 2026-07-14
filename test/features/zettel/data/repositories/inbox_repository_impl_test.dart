import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/services/vault_write_notifier.dart';
import 'package:second_brain/features/zettel/data/datasources/vault_data_source.dart';
import 'package:second_brain/features/zettel/data/repositories/inbox_repository_impl.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';

import '../fakes.dart';

class MockVaultDataSource extends Mock implements VaultDataSource {}

void main() {
  group('with a real vault on disk', () {
    late Directory tempDir;
    late VaultWriteNotifier writeNotifier;
    late InboxRepositoryImpl repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('second_brain_inbox_');
      writeNotifier = VaultWriteNotifier();
      repository = InboxRepositoryImpl(
        FileVaultDataSource(FakeVaultLocator(tempDir.path)),
        writeNotifier,
      );
    });

    tearDown(() async {
      await writeNotifier.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    InboxItem buildItem({
      String id = '20260714110000',
      DateTime? capturedAt,
      InboxStatus status = InboxStatus.pending,
    }) {
      return InboxItem(
        id: id,
        type: CaptureType.clipboard,
        rawText: 'Texte capturé avec accents : déjà vu.',
        capturedAt: capturedAt ?? DateTime(2026, 7, 14, 11, 0),
        status: status,
      );
    }

    test('addItem persists the capture as inbox/<id>.json', () async {
      final result = await repository.addItem(buildItem());

      expect(result.isRight(), isTrue);
      final file = File(p.join(tempDir.path, 'inbox', '20260714110000.json'));
      expect(await file.exists(), isTrue);
    });

    test('getPendingItems returns only pending items, oldest first', () async {
      await repository.addItem(
        buildItem(
          id: '20260714113000',
          capturedAt: DateTime(2026, 7, 14, 11, 30),
        ),
      );
      await repository.addItem(
        buildItem(
          id: '20260714110000',
          capturedAt: DateTime(2026, 7, 14, 11, 0),
        ),
      );
      await repository.addItem(
        buildItem(
          id: '20260714112000',
          capturedAt: DateTime(2026, 7, 14, 11, 20),
          status: InboxStatus.processed,
        ),
      );
      await repository.addItem(
        buildItem(
          id: '20260714112500',
          capturedAt: DateTime(2026, 7, 14, 11, 25),
          status: InboxStatus.discarded,
        ),
      );

      final result = await repository.getPendingItems();

      final ids = result.match(
        (failure) => fail('$failure'),
        (items) => items.map((i) => i.id).toList(),
      );
      expect(ids, ['20260714110000', '20260714113000']);
    });

    test('updateItem rewrites the capture in place', () async {
      final item = buildItem();
      await repository.addItem(item);

      final updated = await repository.updateItem(
        item.copyWith(status: InboxStatus.processed, rawText: 'Traité.'),
      );
      expect(updated.isRight(), isTrue);

      final pending = await repository.getPendingItems();
      expect(pending.match((f) => fail('$f'), (items) => items), isEmpty);
    });

    test('removeItem deletes the file and is idempotent', () async {
      await repository.addItem(buildItem());

      final first = await repository.removeItem('20260714110000');
      expect(first.isRight(), isTrue);
      final file = File(p.join(tempDir.path, 'inbox', '20260714110000.json'));
      expect(await file.exists(), isFalse);

      final second = await repository.removeItem('20260714110000');
      expect(second.isRight(), isTrue);
    });

    test('a corrupt json file is ignored, not fatal', () async {
      await repository.addItem(buildItem());
      await File(
        p.join(tempDir.path, 'inbox', 'broken.json'),
      ).writeAsString('{pas du json');

      final result = await repository.getPendingItems();

      expect(result.match((f) => fail('$f'), (items) => items.length), 1);
    });

    test('every write signals the vault write notifier so captures are '
        'auto-committed even when no zettel is edited', () async {
      var notifications = 0;
      final subscription = writeNotifier.changes.listen((_) => notifications++);

      await repository.addItem(buildItem());
      await repository.updateItem(
        buildItem().copyWith(status: InboxStatus.processed),
      );
      await repository.removeItem('20260714110000');
      // Removing an absent capture must NOT signal a write.
      await repository.removeItem('20260714110000');
      await pumpEventQueue();

      expect(notifications, 3);
      await subscription.cancel();
    });
  });

  group('asset import on addItem', () {
    late Directory tempDir;
    late Directory vaultDir;
    late InboxRepositoryImpl repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('second_brain_asset_');
      vaultDir = Directory(p.join(tempDir.path, 'vault'))..createSync();
      repository = InboxRepositoryImpl(
        FileVaultDataSource(FakeVaultLocator(vaultDir.path)),
        VaultWriteNotifier(),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    InboxItem itemWithAsset(String assetPath, {String id = '20260714120000'}) {
      return InboxItem(
        id: id,
        type: CaptureType.screenshot,
        rawText: 'texte extrait par OCR',
        capturedAt: DateTime(2026, 7, 14, 12, 0),
        assetPath: assetPath,
      );
    }

    test('copies a temporary asset into assets/ and persists a '
        'vault-relative path', () async {
      final source = File(p.join(tempDir.path, 'clipboard-123.png'));
      await source.writeAsBytes([1, 2, 3]);

      final result = await repository.addItem(itemWithAsset(source.path));

      final saved = result.getOrElse((f) => fail('$f'));
      expect(saved.assetPath, p.join('assets', 'clipboard-123.png'));
      final imported = File(
        p.join(vaultDir.path, 'assets', 'clipboard-123.png'),
      );
      expect(imported.existsSync(), isTrue);
      expect(imported.readAsBytesSync(), [1, 2, 3]);
      // The temporary source file is cleaned up after the import.
      expect(source.existsSync(), isFalse);
      // The persisted JSON carries the relative path (reader-compatible).
      final json = File(
        p.join(vaultDir.path, 'inbox', '20260714120000.json'),
      ).readAsStringSync();
      final stored = jsonDecode(json) as Map<String, dynamic>;
      expect(stored['assetPath'], saved.assetPath);
    });

    test('a taken file name falls back to an id-prefixed name', () async {
      final assets = Directory(p.join(vaultDir.path, 'assets'))
        ..createSync(recursive: true);
      await File(p.join(assets.path, 'note.png')).writeAsBytes([9]);
      final source = File(p.join(tempDir.path, 'note.png'));
      await source.writeAsBytes([1]);

      final result = await repository.addItem(
        itemWithAsset(source.path, id: '20260714121500'),
      );

      final saved = result.getOrElse((f) => fail('$f'));
      expect(saved.assetPath, p.join('assets', '20260714121500-note.png'));
      expect(
        File(p.join(assets.path, '20260714121500-note.png')).readAsBytesSync(),
        [1],
      );
      // The pre-existing asset is untouched.
      expect(File(p.join(assets.path, 'note.png')).readAsBytesSync(), [9]);
    });

    test('keeps the original path when the source file is missing', () async {
      final ghost = p.join(tempDir.path, 'gone.png');

      final result = await repository.addItem(itemWithAsset(ghost));

      final saved = result.getOrElse((f) => fail('$f'));
      expect(saved.assetPath, ghost);
    });

    test('leaves an already vault-relative path untouched', () async {
      final result = await repository.addItem(
        itemWithAsset(p.join('assets', 'a.png')),
      );

      final saved = result.getOrElse((f) => fail('$f'));
      expect(saved.assetPath, p.join('assets', 'a.png'));
    });
  });

  group('failure mapping (mocked datasource)', () {
    late MockVaultDataSource dataSource;
    late InboxRepositoryImpl repository;

    setUpAll(() {
      registerFallbackValue(
        InboxItem(
          id: 'fallback',
          type: CaptureType.clipboard,
          rawText: '',
          capturedAt: DateTime(2000),
        ),
      );
    });

    setUp(() {
      dataSource = MockVaultDataSource();
      repository = InboxRepositoryImpl(dataSource, VaultWriteNotifier());
    });

    test('VaultException becomes VaultFailure on read', () async {
      when(
        () => dataSource.readInboxItems(),
      ).thenThrow(const VaultException('coffre non configuré'));

      final result = await repository.getPendingItems();

      result.match(
        (failure) =>
            expect(failure, const VaultFailure('coffre non configuré')),
        (_) => fail('expected a failure'),
      );
    });

    test('VaultException becomes VaultFailure on write', () async {
      when(
        () => dataSource.writeInboxItem(any()),
      ).thenThrow(const VaultException('disque plein'));

      final result = await repository.addItem(
        InboxItem(
          id: '20260714110000',
          type: CaptureType.clipboard,
          rawText: 'x',
          capturedAt: DateTime(2026, 7, 14, 11, 0),
        ),
      );

      result.match(
        (failure) => expect(failure, const VaultFailure('disque plein')),
        (_) => fail('expected a failure'),
      );
    });
  });
}
