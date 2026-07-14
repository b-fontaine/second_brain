import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/core/services/vault_locator.dart';
import 'package:second_brain/features/zettel/data/datasources/vault_data_source.dart';
import 'package:second_brain/features/zettel/data/datasources/zettel_file_naming.dart';
import 'package:second_brain/features/zettel/data/models/inbox_item_model.dart';
import 'package:second_brain/features/zettel/data/models/zettel_model.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';

/// Drop-in replacement for `FileVaultDataSource` backed by SYNCHRONOUS
/// dart:io calls.
///
/// Why: `testWidgets` runs inside a FakeAsync zone where real *async* file
/// IO never completes (the event-loop IO events are not pumped), so the
/// production datasource deadlocks. Synchronous IO bypasses the event loop
/// entirely while still producing REAL markdown/JSON files in the temp
/// vault — steps can assert on the file system and externally-created
/// files are picked up on the next read.
///
/// Behavior mirrors `FileVaultDataSource`: same file naming
/// (`<id>-<slug>.md` via `zettelFileName`), same codecs (`ZettelModel`,
/// `InboxItemModel`), corrupt files skipped, `VaultException` on IO errors.
class SyncFileVaultDataSource implements VaultDataSource {
  SyncFileVaultDataSource(this._locator);

  final VaultLocator _locator;

  static const _zettelFolder = 'zettel';
  static const _inboxFolder = 'inbox';
  static const _assetsFolder = 'assets';

  @override
  Future<List<Zettel>> readAllZettels() async {
    final dir = await _folder(_zettelFolder);
    final zettels = <Zettel>[];
    try {
      for (final entry in dir.listSync(followLinks: false)) {
        if (entry is! File) continue;
        if (zettelIdFromFileName(p.basename(entry.path)) == null) continue;
        final zettel = _tryReadZettelFile(entry);
        if (zettel != null) zettels.add(zettel);
      }
    } on FileSystemException catch (e) {
      throw VaultException('Lecture du coffre impossible : ${e.message}');
    }
    return zettels;
  }

  @override
  Future<Zettel?> readZettelById(ZettelId id) async {
    final dir = await _folder(_zettelFolder);
    final file = _findZettelFile(dir, id);
    if (file == null) return null;
    return _tryReadZettelFile(file);
  }

  @override
  Future<void> writeZettel(Zettel zettel) async {
    final dir = await _folder(_zettelFolder);
    try {
      final previous = _findZettelFiles(dir, zettel.id);
      final target = File(
        p.join(dir.path, zettelFileName(zettel.id, zettel.title)),
      );
      target.writeAsStringSync(ZettelModel.toMarkdown(zettel), flush: true);
      // Mirrors FileVaultDataSource: never delete when several files
      // carry the same id (cross-device creation collision).
      if (previous.length == 1 && previous.single.path != target.path) {
        previous.single.deleteSync();
      }
    } on FileSystemException catch (e) {
      throw VaultException(
        'Écriture de la note ${zettel.id} impossible : ${e.message}',
      );
    }
  }

  @override
  Future<bool> deleteZettel(ZettelId id) async {
    final dir = await _folder(_zettelFolder);
    try {
      final file = _findZettelFile(dir, id);
      if (file == null) return false;
      file.deleteSync();
      return true;
    } on FileSystemException catch (e) {
      throw VaultException(
        'Suppression de la note $id impossible : ${e.message}',
      );
    }
  }

  @override
  Future<bool> zettelExists(ZettelId id) async {
    final dir = await _folder(_zettelFolder);
    return _findZettelFile(dir, id) != null;
  }

  @override
  Future<List<InboxItem>> readInboxItems() async {
    final dir = await _folder(_inboxFolder);
    final items = <InboxItem>[];
    try {
      for (final entry in dir.listSync(followLinks: false)) {
        if (entry is! File) continue;
        if (!entry.path.toLowerCase().endsWith('.json')) continue;
        try {
          items.add(InboxItemModel.fromJsonString(entry.readAsStringSync()));
        } on FormatException {
          continue; // Corrupt capture file: skip, never crash.
        } on FileSystemException {
          continue;
        }
      }
    } on FileSystemException catch (e) {
      throw VaultException(
        'Lecture de la boîte de réception impossible : ${e.message}',
      );
    }
    return items;
  }

  @override
  Future<void> writeInboxItem(InboxItem item) async {
    final dir = await _folder(_inboxFolder);
    try {
      File(
        p.join(dir.path, '${item.id}.json'),
      ).writeAsStringSync(InboxItemModel.toJsonString(item), flush: true);
    } on FileSystemException catch (e) {
      throw VaultException(
        'Écriture de la capture ${item.id} impossible : ${e.message}',
      );
    }
  }

  @override
  Future<bool> deleteInboxItem(String id) async {
    final dir = await _folder(_inboxFolder);
    try {
      final file = File(p.join(dir.path, '$id.json'));
      if (!file.existsSync()) return false;
      file.deleteSync();
      return true;
    } on FileSystemException catch (e) {
      throw VaultException(
        'Suppression de la capture $id impossible : ${e.message}',
      );
    }
  }

  @override
  Future<String> ensureAssetsDirectory() async =>
      (await _folder(_assetsFolder)).path;

  Future<Directory> _folder(String name) async {
    final root = await _locator.vaultPath();
    if (root == null || root.isEmpty) {
      throw const VaultException(
        'Aucun coffre configuré : terminez la configuration initiale',
      );
    }
    try {
      final dir = Directory(p.join(root, name));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    } on FileSystemException catch (e) {
      throw VaultException(
        'Accès au dossier « $name » du coffre impossible : ${e.message}',
      );
    }
  }

  File? _findZettelFile(Directory dir, ZettelId id) {
    final matches = _findZettelFiles(dir, id);
    return matches.isEmpty ? null : matches.first;
  }

  List<File> _findZettelFiles(Directory dir, ZettelId id) {
    final matches = <File>[];
    try {
      for (final entry in dir.listSync(followLinks: false)) {
        if (entry is! File) continue;
        final fileId = zettelIdFromFileName(p.basename(entry.path));
        if (fileId != null && fileId.value == id.value) matches.add(entry);
      }
    } on FileSystemException catch (e) {
      throw VaultException('Lecture du coffre impossible : ${e.message}');
    }
    matches.sort((a, b) => a.path.compareTo(b.path));
    return matches;
  }

  Zettel? _tryReadZettelFile(File file) {
    try {
      return ZettelModel.fromMarkdown(file.readAsStringSync());
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }
}
