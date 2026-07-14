import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slugify/slugify.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/clock.dart';
import '../models/vault_config_model.dart';
import 'documents_directory_provider.dart';

/// Local persistence for the onboarding: config in `SharedPreferences`,
/// PAT in the platform secure storage, vault folder on disk.
abstract interface class SetupLocalDataSource {
  /// Null when the app has never been configured.
  Future<VaultConfigModel?> getConfig();

  Future<void> saveConfig(VaultConfigModel config);

  /// Stores the git personal access token under the `git_token` key.
  Future<void> storeToken(String token);

  /// `<application documents>/second_brain_vault`.
  Future<String> defaultVaultPath();

  /// Creates the vault root directory (recursive, idempotent).
  Future<void> createVaultDirectory(String vaultPath);

  /// Creates `zettel/`, `inbox/`, `assets/` and the two French welcome
  /// notes (linked together with a `[[id]]` wikilink).
  Future<void> createLocalVaultStructure(String vaultPath);
}

@LazySingleton(as: SetupLocalDataSource)
class SetupLocalDataSourceImpl implements SetupLocalDataSource {
  SetupLocalDataSourceImpl(
    this._secureStorage,
    this._documentsDirectoryProvider,
    this._clock,
  );

  final FlutterSecureStorage _secureStorage;
  final DocumentsDirectoryProvider _documentsDirectoryProvider;
  final Clock _clock;

  static const vaultPathKey = 'vault_path';
  static const remoteUrlKey = 'remote_url';
  static const gitTokenKey = 'git_token';
  static const vaultDirectoryName = 'second_brain_vault';

  static final _idFormat = DateFormat('yyyyMMddHHmmss');

  @override
  Future<VaultConfigModel?> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final vaultPath = prefs.getString(vaultPathKey);
    if (vaultPath == null || vaultPath.isEmpty) return null;
    return VaultConfigModel(
      vaultPath: vaultPath,
      remoteUrl: prefs.getString(remoteUrlKey),
    );
  }

  @override
  Future<void> saveConfig(VaultConfigModel config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(vaultPathKey, config.vaultPath);
    final remoteUrl = config.remoteUrl;
    if (remoteUrl == null || remoteUrl.isEmpty) {
      await prefs.remove(remoteUrlKey);
    } else {
      await prefs.setString(remoteUrlKey, remoteUrl);
    }
  }

  @override
  Future<void> storeToken(String token) async {
    try {
      await _secureStorage.write(key: gitTokenKey, value: token);
    } on Exception catch (e) {
      throw GitException("Impossible d'enregistrer le jeton d'accès : $e");
    }
  }

  @override
  Future<String> defaultVaultPath() async {
    final documents = await _documentsDirectoryProvider.documentsDirectory();
    return p.join(documents.path, vaultDirectoryName);
  }

  @override
  Future<void> createVaultDirectory(String vaultPath) async {
    try {
      await Directory(vaultPath).create(recursive: true);
    } on FileSystemException catch (e) {
      throw VaultException(
        'Impossible de créer le dossier du coffre : ${e.message}',
      );
    }
  }

  @override
  Future<void> createLocalVaultStructure(String vaultPath) async {
    try {
      final zettelDir = Directory(p.join(vaultPath, 'zettel'));
      await zettelDir.create(recursive: true);
      await Directory(p.join(vaultPath, 'inbox')).create(recursive: true);
      await Directory(p.join(vaultPath, 'assets')).create(recursive: true);

      final now = _clock.now();
      final welcomeId = _idFormat.format(now);
      final linkingId = _idFormat.format(now.add(const Duration(seconds: 1)));

      const welcomeTitle = 'Bienvenue dans Second Brain';
      const linkingTitle = 'Comment lier ses notes';

      await File(
        p.join(zettelDir.path, '$welcomeId-${slugify(welcomeTitle)}.md'),
      ).writeAsString(
        _welcomeNote(
          id: welcomeId,
          title: welcomeTitle,
          date: now,
          linkingId: linkingId,
          linkingTitle: linkingTitle,
        ),
      );
      await File(
        p.join(zettelDir.path, '$linkingId-${slugify(linkingTitle)}.md'),
      ).writeAsString(
        _linkingNote(
          id: linkingId,
          title: linkingTitle,
          date: now.add(const Duration(seconds: 1)),
          welcomeId: welcomeId,
        ),
      );
    } on FileSystemException catch (e) {
      throw VaultException(
        'Impossible de créer la structure du coffre : ${e.message}',
      );
    }
  }

  String _welcomeNote({
    required String id,
    required String title,
    required DateTime date,
    required String linkingId,
    required String linkingTitle,
  }) {
    return '''
---
id: "$id"
title: $title
date: ${date.toIso8601String()}
tags: [bienvenue, zettelkasten]
---

Bienvenue ! Ce coffre est votre **Zettelkasten** : une boîte à notes où chaque
fichier contient une seule idée, exprimée avec vos propres mots.

Quelques principes :

- **Une note = une idée.** Les notes courtes et atomiques se recombinent mieux.
- **Reliez vos notes entre elles.** C'est le réseau de liens qui fait émerger
  la connaissance, pas le classement en dossiers.
- **Capturez d'abord, organisez ensuite.** Tout ce que vous capturez arrive
  dans l'inbox ; rien ne se perd.

Pour créer votre premier lien, ouvrez [[$linkingId|$linkingTitle]].

## Références

- https://zettelkasten.de
''';
  }

  String _linkingNote({
    required String id,
    required String title,
    required DateTime date,
    required String welcomeId,
  }) {
    return '''
---
id: "$id"
title: $title
date: ${date.toIso8601String()}
tags: [bienvenue, zettelkasten]
---

Un lien s'écrit entre doubles crochets avec l'identifiant de la note cible :
`[[$welcomeId]]`, ou avec un libellé : `[[$welcomeId|texte affiché]]`.

Chaque note possède un identifiant horodaté unique. Pendant la rédaction,
ajoutez un lien dès qu'une idée en rappelle une autre : les rétroliens sont
calculés automatiquement et s'affichent sous chaque note.
''';
  }
}
