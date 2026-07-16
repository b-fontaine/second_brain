import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/vault_write_notifier.dart';
import '../../domain/entities/inbox_item.dart';
import '../../domain/repositories/inbox_repository.dart';
import '../datasources/vault_data_source.dart';

/// Vault-backed implementation of [InboxRepository].
///
/// Each capture lives as a small `inbox/<id>.json` file so nothing is
/// ever lost, even when the AI assistant is unavailable. Every write is
/// signalled through [VaultWriteNotifier] so the sync loop commits and
/// pushes captures even when no zettel is edited afterwards. A captured
/// asset (clipboard image, audio file...) is imported into the vault's
/// `assets/` folder on add and persisted with a vault-relative path.
@LazySingleton(as: InboxRepository)
class InboxRepositoryImpl implements InboxRepository {
  InboxRepositoryImpl(this._dataSource, this._writeNotifier);

  final VaultDataSource _dataSource;
  final VaultWriteNotifier _writeNotifier;

  static const _assetsFolder = 'assets';

  @override
  Future<Either<Failure, InboxItem>> addItem(InboxItem item) =>
      _guard(() async {
        final toPersist = await _withImportedAsset(item);
        await _dataSource.writeInboxItem(toPersist);
        _writeNotifier.notifyWrite();
        return Right(toPersist);
      });

  @override
  Future<Either<Failure, List<InboxItem>>> getPendingItems() =>
      _guard(() async {
        final items = await _dataSource.readInboxItems();
        final pending =
            items.where((item) => item.status == InboxStatus.pending).toList()
              // Oldest first: captures are processed as a FIFO queue.
              ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
        return Right(pending);
      });

  @override
  Future<Either<Failure, InboxItem>> updateItem(InboxItem item) =>
      _guard(() async {
        // Upsert semantics: the JSON file is rewritten in place.
        await _dataSource.writeInboxItem(item);
        _writeNotifier.notifyWrite();
        return Right(item);
      });

  @override
  Future<Either<Failure, Unit>> removeItem(String id) => _guard(() async {
    // Idempotent: removing an already absent capture succeeds.
    final removed = await _dataSource.deleteInboxItem(id);
    if (removed) _writeNotifier.notifyWrite();
    return const Right(unit);
  });

  /// Copies the captured asset — often a volatile temporary or cache file
  /// (clipboard PNG, image_picker cache) — into the vault's `assets/`
  /// folder and rewrites the path to the vault-relative `assets/<file>`,
  /// so provenance survives temp purges and git sync to another machine.
  /// Best effort: when the import fails, the original path is kept rather
  /// than losing the capture itself.
  Future<InboxItem> _withImportedAsset(InboxItem item) async {
    final assetPath = item.assetPath;
    if (assetPath == null || assetPath.isEmpty) return item;
    // Already vault-relative: nothing to import.
    if (!p.isAbsolute(assetPath)) return item;
    try {
      final source = File(assetPath);
      if (!source.existsSync()) return item;
      final assetsDir = await _dataSource.ensureAssetsDirectory();
      if (p.isWithin(assetsDir, assetPath)) {
        // The file already lives in the vault: only relativize the path.
        return _withAssetPath(
          item,
          p.join(_assetsFolder, p.relative(assetPath, from: assetsDir)),
        );
      }
      var name = p.basename(assetPath);
      if (File(p.join(assetsDir, name)).existsSync()) {
        // Keep the original name unless taken: prefix with the item id.
        name = '${item.id}-$name';
      }
      await source.copy(p.join(assetsDir, name));
      _cleanUpTemporary(source);
      return _withAssetPath(item, p.join(_assetsFolder, name));
    } on FileSystemException {
      return item;
    }
  }

  /// Deletes [source] when it lives under the system temporary directory
  /// (e.g. clipboard captures); user-picked files elsewhere on disk are
  /// never touched.
  void _cleanUpTemporary(File source) {
    try {
      final temp = Directory.systemTemp.resolveSymbolicLinksSync();
      if (p.isWithin(temp, source.resolveSymbolicLinksSync())) {
        source.deleteSync();
      }
    } on FileSystemException {
      // Cleanup is best effort only.
    }
  }

  /// [InboxItem.copyWith] does not expose assetPath (domain callers never
  /// rewrite it); the import rewrite is a data-layer concern kept here.
  /// Every other field is carried over — the enriched title and parcelles
  /// of a seeded image/audio capture must survive the asset import.
  static InboxItem _withAssetPath(InboxItem item, String assetPath) {
    return InboxItem(
      id: item.id,
      type: item.type,
      rawText: item.rawText,
      capturedAt: item.capturedAt,
      assetPath: assetPath,
      title: item.title,
      tags: item.tags,
      status: item.status,
    );
  }

  Future<Either<Failure, T>> _guard<T>(
    Future<Either<Failure, T>> Function() action,
  ) async {
    try {
      return await action();
    } on VaultException catch (e) {
      return Left(VaultFailure(e.message));
    } on Exception catch (e) {
      return Left(VaultFailure('Erreur inattendue du coffre : $e'));
    }
  }
}
