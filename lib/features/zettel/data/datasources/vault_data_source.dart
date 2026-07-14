import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/vault_locator.dart';
import '../../domain/entities/inbox_item.dart';
import '../../domain/entities/zettel.dart';
import '../../domain/entities/zettel_id.dart';
import '../models/inbox_item_model.dart';
import '../models/zettel_model.dart';
import 'zettel_file_naming.dart';

/// File-system access to the markdown vault.
///
/// The vault root comes from [VaultLocator]; the `zettel/`, `inbox/` and
/// `assets/` sub-folders are created on demand. All methods throw
/// [VaultException] on IO errors — repositories convert those to failures.
abstract interface class VaultDataSource {
  /// All parseable zettels of `zettel/`. Corrupt files are skipped.
  Future<List<Zettel>> readAllZettels();

  /// The zettel whose file carries [id], or null when absent/corrupt.
  Future<Zettel?> readZettelById(ZettelId id);

  /// Writes (creates or overwrites) the zettel file `<id>-<slug>.md`.
  /// When the title changed, the previous file of the same id is removed.
  Future<void> writeZettel(Zettel zettel);

  /// Deletes the zettel file; returns false when no file carries [id].
  Future<bool> deleteZettel(ZettelId id);

  /// Whether a file of `zettel/` carries [id].
  Future<bool> zettelExists(ZettelId id);

  /// All parseable inbox items of `inbox/`. Corrupt files are skipped.
  Future<List<InboxItem>> readInboxItems();

  /// Writes (creates or overwrites) `inbox/<id>.json`.
  Future<void> writeInboxItem(InboxItem item);

  /// Deletes `inbox/<id>.json`; returns false when absent.
  Future<bool> deleteInboxItem(String id);

  /// Creates `assets/` if needed and returns its absolute path.
  Future<String> ensureAssetsDirectory();
}

@LazySingleton(as: VaultDataSource)
class FileVaultDataSource implements VaultDataSource {
  FileVaultDataSource(this._locator);

  final VaultLocator _locator;

  static const _zettelFolder = 'zettel';
  static const _inboxFolder = 'inbox';
  static const _assetsFolder = 'assets';

  @override
  Future<List<Zettel>> readAllZettels() async {
    final dir = await _folder(_zettelFolder);
    final zettels = <Zettel>[];
    try {
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is! File) continue;
        if (zettelIdFromFileName(p.basename(entry.path)) == null) continue;
        final zettel = await _tryReadZettelFile(entry);
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
    final file = await _findZettelFile(dir, id);
    if (file == null) return null;
    return _tryReadZettelFile(file);
  }

  @override
  Future<void> writeZettel(Zettel zettel) async {
    final dir = await _folder(_zettelFolder);
    try {
      final previous = await _findZettelFiles(dir, zettel.id);
      final target = File(
        p.join(dir.path, zettelFileName(zettel.id, zettel.title)),
      );
      await target.writeAsString(ZettelModel.toMarkdown(zettel), flush: true);
      // Title changed => slug changed: drop the obsolete file after the
      // new one is safely on disk (no data-loss window). When several
      // files carry the same id (two devices created notes within the
      // same second, merged by git), delete NOTHING: any of those files
      // may be the only copy of another note.
      if (previous.length == 1 && previous.single.path != target.path) {
        await previous.single.delete();
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
      final file = await _findZettelFile(dir, id);
      if (file == null) return false;
      await file.delete();
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
    return await _findZettelFile(dir, id) != null;
  }

  @override
  Future<List<InboxItem>> readInboxItems() async {
    final dir = await _folder(_inboxFolder);
    final items = <InboxItem>[];
    try {
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is! File) continue;
        if (!entry.path.toLowerCase().endsWith('.json')) continue;
        try {
          items.add(InboxItemModel.fromJsonString(await entry.readAsString()));
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
      final file = File(p.join(dir.path, '${item.id}.json'));
      await file.writeAsString(InboxItemModel.toJsonString(item), flush: true);
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
      if (!await file.exists()) return false;
      await file.delete();
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

  /// Returns the requested vault sub-folder, creating it on demand.
  Future<Directory> _folder(String name) async {
    final root = await _locator.vaultPath();
    if (root == null || root.isEmpty) {
      throw const VaultException(
        'Aucun coffre configuré : terminez la configuration initiale',
      );
    }
    try {
      final dir = Directory(p.join(root, name));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } on FileSystemException catch (e) {
      throw VaultException(
        'Accès au dossier « $name » du coffre impossible : ${e.message}',
      );
    }
  }

  /// The file of `zettel/` carrying [id] in its name (deterministic pick
  /// when several match), or null.
  Future<File?> _findZettelFile(Directory dir, ZettelId id) async {
    final matches = await _findZettelFiles(dir, id);
    return matches.isEmpty ? null : matches.first;
  }

  /// Every file of `zettel/` carrying [id] in its name, sorted by path so
  /// callers make deterministic picks. Several matches indicate an id
  /// collision (same-second creations on two devices merged by git).
  Future<List<File>> _findZettelFiles(Directory dir, ZettelId id) async {
    final matches = <File>[];
    try {
      await for (final entry in dir.list(followLinks: false)) {
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

  /// Reads and decodes one zettel file; returns null when the file is
  /// corrupt or vanished, so a single bad file never breaks the vault.
  Future<Zettel?> _tryReadZettelFile(File file) async {
    try {
      return ZettelModel.fromMarkdown(await file.readAsString());
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }
}
