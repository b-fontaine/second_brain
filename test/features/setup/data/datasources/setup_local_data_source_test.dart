import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/core/services/clock.dart';
import 'package:second_brain/features/setup/data/datasources/documents_directory_provider.dart';
import 'package:second_brain/features/setup/data/datasources/setup_local_data_source.dart';
import 'package:second_brain/features/setup/data/models/vault_config_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _FakeDocumentsDirectoryProvider implements DocumentsDirectoryProvider {
  _FakeDocumentsDirectoryProvider(this.directory);

  final Directory directory;

  @override
  Future<Directory> documentsDirectory() async => directory;
}

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime(2026, 7, 14, 10, 30);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockSecureStorage secureStorage;
  late SetupLocalDataSourceImpl dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('setup_local_ds_test');
    SharedPreferences.setMockInitialValues({});
    secureStorage = MockSecureStorage();
    dataSource = SetupLocalDataSourceImpl(
      secureStorage,
      _FakeDocumentsDirectoryProvider(tempDir),
      _FixedClock(),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('config persistence', () {
    test('getConfig returns null on first run', () async {
      expect(await dataSource.getConfig(), isNull);
    });

    test('saveConfig / getConfig round-trips a remote config', () async {
      const config = VaultConfigModel(
        vaultPath: '/docs/second_brain_vault',
        remoteUrl: 'https://github.com/user/notes.git',
      );

      await dataSource.saveConfig(config);
      final loaded = await dataSource.getConfig();

      expect(loaded, isNotNull);
      expect(loaded!.vaultPath, '/docs/second_brain_vault');
      expect(loaded.remoteUrl, 'https://github.com/user/notes.git');
      expect(loaded.hasRemote, isTrue);
    });

    test('saving a local-only config clears any previous remote url', () async {
      await dataSource.saveConfig(
        const VaultConfigModel(
          vaultPath: '/docs/second_brain_vault',
          remoteUrl: 'https://github.com/user/notes.git',
        ),
      );
      await dataSource.saveConfig(
        const VaultConfigModel(vaultPath: '/docs/second_brain_vault'),
      );

      final loaded = await dataSource.getConfig();

      expect(loaded!.remoteUrl, isNull);
      expect(loaded.hasRemote, isFalse);
    });
  });

  group('storeToken', () {
    test('writes the token under the git_token key', () async {
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await dataSource.storeToken('ghp_token123');

      verify(
        () => secureStorage.write(key: 'git_token', value: 'ghp_token123'),
      ).called(1);
    });

    test('wraps storage errors in GitException', () async {
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenThrow(Exception('keychain unavailable'));

      expect(
        () => dataSource.storeToken('ghp_token123'),
        throwsA(isA<GitException>()),
      );
    });
  });

  test(
    'defaultVaultPath is second_brain_vault under the documents directory',
    () async {
      final path = await dataSource.defaultVaultPath();

      expect(path, p.join(tempDir.path, 'second_brain_vault'));
    },
  );

  test('createVaultDirectory creates the folder recursively', () async {
    final vaultPath = p.join(tempDir.path, 'nested', 'second_brain_vault');

    await dataSource.createVaultDirectory(vaultPath);

    expect(Directory(vaultPath).existsSync(), isTrue);
  });

  group('createLocalVaultStructure', () {
    late String vaultPath;

    setUp(() async {
      vaultPath = p.join(tempDir.path, 'second_brain_vault');
      await dataSource.createVaultDirectory(vaultPath);
    });

    test('creates zettel/, inbox/ and assets/', () async {
      await dataSource.createLocalVaultStructure(vaultPath);

      expect(Directory(p.join(vaultPath, 'zettel')).existsSync(), isTrue);
      expect(Directory(p.join(vaultPath, 'inbox')).existsSync(), isTrue);
      expect(Directory(p.join(vaultPath, 'assets')).existsSync(), isTrue);
    });

    test('writes two linked welcome notes with valid frontmatter', () async {
      await dataSource.createLocalVaultStructure(vaultPath);

      final welcomeFile = File(
        p.join(
          vaultPath,
          'zettel',
          '20260714103000-bienvenue-dans-second-brain.md',
        ),
      );
      final linkingFile = File(
        p.join(vaultPath, 'zettel', '20260714103001-comment-lier-ses-notes.md'),
      );
      expect(welcomeFile.existsSync(), isTrue);
      expect(linkingFile.existsSync(), isTrue);

      final welcome = await welcomeFile.readAsString();
      expect(welcome, startsWith('---\n'));
      expect(welcome, contains('id: "20260714103000"'));
      expect(welcome, contains('title: Bienvenue dans Second Brain'));
      expect(welcome, contains('Zettelkasten'));
      // Example wikilink towards the second note.
      expect(welcome, contains('[[20260714103001|Comment lier ses notes]]'));

      final linking = await linkingFile.readAsString();
      expect(linking, contains('id: "20260714103001"'));
      expect(linking, contains('title: Comment lier ses notes'));
      expect(linking, contains('[[20260714103000]]'));
    });

    test('is idempotent', () async {
      await dataSource.createLocalVaultStructure(vaultPath);
      await dataSource.createLocalVaultStructure(vaultPath);

      final notes = Directory(
        p.join(vaultPath, 'zettel'),
      ).listSync().whereType<File>().toList();
      expect(notes, hasLength(2));
    });
  });
}
