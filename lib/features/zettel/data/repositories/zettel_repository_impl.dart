import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/clock.dart';
import '../../domain/entities/zettel.dart';
import '../../domain/entities/zettel_id.dart';
import '../../domain/repositories/zettel_repository.dart';
import '../datasources/vault_data_source.dart';
import '../models/zettel_model.dart';
import 'search_normalizer.dart';

/// Vault-backed implementation of [ZettelRepository].
///
/// Keeps a lazily loaded in-memory index of the whole vault (entity +
/// pre-normalized search text + outgoing link ids) sized for ~2000 notes.
/// Internal mutations update the index incrementally; external changes
/// (git pull) must be signalled through [notifyExternalChange], which
/// drops the index and re-emits [VaultChanged].
/// Top-level dispose hook: injectable registers the singleton under the
/// [ZettelRepository] interface, which has no dispose() of its own.
FutureOr<void> disposeZettelRepository(ZettelRepository repository) {
  if (repository is ZettelRepositoryImpl) return repository.dispose();
}

@LazySingleton(as: ZettelRepository, dispose: disposeZettelRepository)
class ZettelRepositoryImpl implements ZettelRepository {
  ZettelRepositoryImpl(this._dataSource, this._clock);

  final VaultDataSource _dataSource;
  final Clock _clock;

  final StreamController<VaultChanged> _changes =
      StreamController<VaultChanged>.broadcast();

  Map<String, _IndexEntry>? _index;
  Future<Map<String, _IndexEntry>>? _indexLoading;

  /// Bumped by [notifyExternalChange] so a load already in flight when a
  /// pull rewrites the vault can never install its stale (pre-pull)
  /// snapshot as the current index.
  int _indexGeneration = 0;

  @override
  Future<Either<Failure, List<Zettel>>> getAllZettels() => _guard(() async {
    final index = await _ensureIndex();
    return Right(_sortedRecentFirst(index.values.map((e) => e.zettel)));
  });

  @override
  Future<Either<Failure, Zettel>> getZettelById(ZettelId id) =>
      _guard(() async {
        final index = await _ensureIndex();
        final entry = index[id.value];
        if (entry == null) return Left(ZettelNotFoundFailure(id.value));
        return Right(entry.zettel);
      });

  @override
  Future<Either<Failure, Zettel>> createZettel({
    required String title,
    required String body,
    List<String> tags = const [],
    String? source,
  }) => _guard(() async {
    final index = await _ensureIndex();

    // Mint a unique timestamp id; on collision (two creations within
    // the same second) bump the second until a free slot is found.
    var moment = ZettelModel.truncateToSecond(_clock.now());
    var id = ZettelId.fromDateTime(moment);
    while (index.containsKey(id.value) || await _dataSource.zettelExists(id)) {
      moment = moment.add(const Duration(seconds: 1));
      id = ZettelId.fromDateTime(moment);
    }

    final zettel = ZettelModel.normalize(
      Zettel(
        id: id,
        title: title,
        body: body,
        createdAt: moment,
        tags: tags,
        source: source,
      ),
    );
    await _dataSource.writeZettel(zettel);
    index[id.value] = _IndexEntry(zettel);
    _changes.add(const VaultChanged());
    return Right(zettel);
  });

  @override
  Future<Either<Failure, Zettel>> updateZettel(Zettel zettel) =>
      _guard(() async {
        final index = await _ensureIndex();
        if (!index.containsKey(zettel.id.value)) {
          return Left(ZettelNotFoundFailure(zettel.id.value));
        }
        final normalized = ZettelModel.normalize(zettel);
        await _dataSource.writeZettel(normalized);
        index[normalized.id.value] = _IndexEntry(normalized);
        _changes.add(const VaultChanged());
        return Right(normalized);
      });

  @override
  Future<Either<Failure, Unit>> deleteZettel(ZettelId id) => _guard(() async {
    final index = await _ensureIndex();
    if (!index.containsKey(id.value)) {
      return Left(ZettelNotFoundFailure(id.value));
    }
    await _dataSource.deleteZettel(id);
    index.remove(id.value);
    _changes.add(const VaultChanged());
    return const Right(unit);
  });

  @override
  Future<Either<Failure, List<Zettel>>> searchZettels(String query) =>
      _guard(() async {
        final index = await _ensureIndex();
        final tokens = normalizeForSearch(
          query,
        ).split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toList();
        if (tokens.isEmpty) {
          return Right(_sortedRecentFirst(index.values.map((e) => e.zettel)));
        }
        final matches = index.values
            .where((e) => tokens.every(e.searchText.contains))
            .map((e) => e.zettel);
        return Right(_sortedRecentFirst(matches));
      });

  @override
  Future<Either<Failure, List<Zettel>>> getBacklinks(ZettelId id) =>
      _guard(() async {
        final index = await _ensureIndex();
        final matches = index.values
            .where((e) => e.outgoingIds.contains(id.value))
            .map((e) => e.zettel);
        return Right(_sortedRecentFirst(matches));
      });

  @override
  Stream<VaultChanged> watchVault() => _changes.stream;

  /// Called by the sync feature after a git pull rewrote vault files:
  /// drops the in-memory index (reloaded lazily) — including any load
  /// still in flight, whose snapshot predates the pull — and notifies
  /// watchers.
  void notifyExternalChange() {
    _indexGeneration++;
    _index = null;
    _indexLoading = null;
    _changes.add(const VaultChanged());
  }

  Future<void> dispose() => _changes.close();

  /// Runs [action], converting data-layer exceptions into [Failure]s.
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

  Future<Map<String, _IndexEntry>> _ensureIndex() {
    final cached = _index;
    if (cached != null) return Future.value(cached);
    return _indexLoading ??= _loadIndex();
  }

  Future<Map<String, _IndexEntry>> _loadIndex() async {
    final generation = _indexGeneration;
    try {
      final zettels = await _dataSource.readAllZettels();
      final index = <String, _IndexEntry>{
        for (final zettel in zettels) zettel.id.value: _IndexEntry(zettel),
      };
      // Stale snapshot (a pull landed during the read): return it to the
      // caller of the moment but never cache it — the next access reloads.
      if (generation == _indexGeneration) _index = index;
      return index;
    } finally {
      // Same guard: a newer load may already be registered.
      if (generation == _indexGeneration) _indexLoading = null;
    }
  }

  List<Zettel> _sortedRecentFirst(Iterable<Zettel> zettels) {
    final list = zettels.toList()
      ..sort((a, b) => b.id.value.compareTo(a.id.value));
    return list;
  }
}

/// One indexed zettel with its precomputed search text and outgoing links.
class _IndexEntry {
  _IndexEntry(this.zettel)
    : searchText = normalizeForSearch(
        '${zettel.title}\n${zettel.body}\n${zettel.tags.join(' ')}',
      ),
      outgoingIds = {for (final id in zettel.outgoingLinks) id.value};

  final Zettel zettel;
  final String searchText;
  final Set<String> outgoingIds;
}
