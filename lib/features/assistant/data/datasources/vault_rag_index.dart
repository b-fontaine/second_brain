import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../../zettel/domain/entities/zettel.dart';
import '../../../zettel/domain/entities/zettel_id.dart';
import '../../../zettel/domain/repositories/zettel_repository.dart';
import 'rag_embeddings_gateway.dart';

/// Retrieval index over the vault used by the assistant (RAG).
///
/// Two retrieval strategies:
/// - semantic search through [RagEmbeddingsGateway] when an embedding model
///   is installed (flutter_gemma_embeddings + sqlite vector store);
/// - an always-available accent-insensitive keyword (term-frequency) index,
///   used as fallback so the assistant works without any embedding model.
///
/// The index rebuilds incrementally whenever [ZettelRepository.watchVault]
/// fires: only added/changed zettels are re-embedded. The vector store has
/// no per-document delete, so a deletion clears it and re-embeds the
/// remaining corpus; as a safety net, hits for zettels no longer in the
/// vault are also filtered out at query time.
@lazySingleton
class VaultRagIndex {
  VaultRagIndex(this._zettelRepository, this._embeddingsGateway) {
    _vaultSubscription = _zettelRepository.watchVault().listen((_) {
      _scheduleRefresh();
    });
  }

  final ZettelRepository _zettelRepository;
  final RagEmbeddingsGateway _embeddingsGateway;

  StreamSubscription<VaultChanged>? _vaultSubscription;
  Future<void>? _refreshFuture;
  bool _builtOnce = false;

  /// Whether the previous refresh ran with a usable embedder. When it flips
  /// to true, the whole corpus is re-embedded: zettels indexed before the
  /// embedder was installed would otherwise never reach the vector store.
  bool _wasEmbeddingsReady = false;

  /// Indexed documents keyed by zettel id.
  final Map<String, _IndexedZettel> _documents = {};

  /// Returns the [k] most relevant zettels for [query], best first, as
  /// `(id, excerpt)` pairs. Uses semantic search when embeddings are ready,
  /// keyword scoring otherwise. Never throws: degraded results over errors.
  Future<List<(ZettelId, String)>> topK(String query, {int k = 5}) async => [
    for (final (id, excerpt, _) in await topKScored(query, k: k)) (id, excerpt),
  ];

  /// Like [topK] but keeps the relevance score: the cosine similarity
  /// normalized to `[0, 1]` on the semantic path, or null on the keyword
  /// path (raw term-frequency scores are unbounded and not comparable
  /// across queries, so only the rank is meaningful there).
  Future<List<(ZettelId, String, double?)>> topKScored(
    String query, {
    int k = 5,
  }) async {
    await _ensureIndexed();
    final queryTerms = tokenize(query);
    if (queryTerms.isEmpty && query.trim().isEmpty) return const [];
    if (_documents.isEmpty || k <= 0) return const [];

    if (await _gatewayAvailable()) {
      try {
        final hits = await _embeddingsGateway.search(query, k);
        final results = <(ZettelId, String, double?)>[];
        for (final hit in hits) {
          // Skip stale hits (zettel deleted since it was embedded).
          final document = _documents[hit.id];
          if (document == null) continue;
          results.add((
            document.id,
            _excerpt(document, queryTerms),
            hit.similarity.clamp(0.0, 1.0).toDouble(),
          ));
        }
        if (results.isNotEmpty) return results;
      } catch (_) {
        // Semantic search failed — degrade to keyword scoring below.
      }
    }
    return [
      for (final (id, excerpt) in _keywordTopK(queryTerms, k))
        (id, excerpt, null),
    ];
  }

  /// Forces a full (re)index pass. Normally not needed: indexing is lazy on
  /// first [topK] and incremental on vault changes.
  Future<void> rebuild() {
    _scheduleRefresh();
    return _refreshFuture ?? Future<void>.value();
  }

  @disposeMethod
  void dispose() {
    // Fire-and-forget on purpose: awaiting this cancel would await a future
    // completed in the subscription's creation zone. Under the BDD harness,
    // that zone is the FakeAsync zone of a finished test — the await would
    // never resolve and would deadlock the next scenario's getIt.reset().
    unawaited(_vaultSubscription?.cancel());
    _vaultSubscription = null;
  }

  // --- Keyword (term frequency) index -------------------------------------

  List<(ZettelId, String)> _keywordTopK(List<String> queryTerms, int k) {
    if (queryTerms.isEmpty) return const [];
    final scored = <(_IndexedZettel, int)>[];
    for (final document in _documents.values) {
      var score = 0;
      for (final term in queryTerms) {
        score += document.termFrequencies[term] ?? 0;
      }
      if (score > 0) scored.add((document, score));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      // Deterministic tie-break: most recent zettel first.
      return b.$1.id.value.compareTo(a.$1.id.value);
    });
    return [
      for (final (document, _) in scored.take(k))
        (document.id, _excerpt(document, queryTerms)),
    ];
  }

  /// Lowercases and strips diacritics so `memoire` matches `Mémoire`.
  static String normalize(String input) {
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_diacritics[char] ?? char);
    }
    return buffer.toString();
  }

  /// Splits [text] into normalized index terms (1-char tokens dropped, which
  /// also discards French elisions such as « l' » or « d' »).
  static List<String> tokenize(String text) {
    return normalize(
      text,
    ).split(_nonWord).where((token) => token.length > 1).toList();
  }

  static final RegExp _nonWord = RegExp(r'[^a-z0-9]+');

  static const Map<String, String> _diacritics = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ã': 'a',
    'å': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ì': 'i',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ù': 'u',
    'ÿ': 'y',
    'ý': 'y',
    'ñ': 'n',
    'œ': 'oe',
    'æ': 'ae',
  };

  /// Same normalization but guaranteed 1:1 in length (œ→o, æ→a), so an index
  /// into the normalized string is a valid index into the original.
  static String _normalizeSameLength(String input) {
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final mapped = _diacritics[char] ?? char;
      buffer.write(mapped.length == 1 ? mapped : mapped[0]);
    }
    return buffer.toString();
  }

  String _excerpt(_IndexedZettel document, List<String> queryTerms) {
    const window = 160;
    final body = document.body.trim();
    if (body.isEmpty) return document.title;

    final normalizedBody = _normalizeSameLength(body);
    var matchIndex = -1;
    for (final term in queryTerms) {
      matchIndex = normalizedBody.indexOf(term);
      if (matchIndex >= 0) break;
    }
    if (matchIndex < 0) {
      return body.length <= window
          ? body
          : '${body.substring(0, window).trimRight()}…';
    }
    var start = matchIndex - window ~/ 2;
    if (start < 0) start = 0;
    var end = start + window;
    if (end > body.length) end = body.length;
    final prefix = start > 0 ? '…' : '';
    final suffix = end < body.length ? '…' : '';
    return '$prefix${body.substring(start, end).trim()}$suffix';
  }

  // --- Incremental indexing ------------------------------------------------

  Future<void> _ensureIndexed() async {
    if (!_builtOnce && _refreshFuture == null) {
      _scheduleRefresh();
    }
    final pending = _refreshFuture;
    if (pending != null) await pending;
  }

  /// Serializes refreshes: a change arriving mid-refresh queues another pass.
  void _scheduleRefresh() {
    final previous = _refreshFuture;
    if (previous == null) {
      _refreshFuture = _refresh();
    } else {
      _refreshFuture = previous.then(
        (_) => _refresh(),
        onError: (Object _) => _refresh(),
      );
    }
  }

  Future<void> _refresh() async {
    List<Zettel>? zettels;
    try {
      final result = await _zettelRepository.getAllZettels();
      zettels = result.fold<List<Zettel>?>((_) => null, (list) => list);
    } catch (_) {
      zettels = null;
    }
    // On read failure keep the previous index (degraded, not broken).
    if (zettels == null) return;

    final embeddingsReady = await _gatewayAvailable();
    final liveIds = <String>{for (final zettel in zettels) zettel.id.value};

    // Re-embed the whole corpus the first time the embedder becomes
    // available (documents indexed before its installation never reached
    // the vector store), and after a deletion: the store has no
    // per-document delete, so eviction is clear + re-upsert — which also
    // keeps the store from growing without bound.
    var reembedAll = embeddingsReady && !_wasEmbeddingsReady;
    if (embeddingsReady &&
        _documents.keys.any((key) => !liveIds.contains(key))) {
      try {
        await _embeddingsGateway.clear();
        reembedAll = true;
      } catch (_) {
        // Clearing failed: stale hits keep being filtered at query time.
      }
    }

    for (final zettel in zettels) {
      final key = zettel.id.value;
      final content = '${zettel.title}\n${zettel.body}';
      final existing = _documents[key];
      final changed = existing == null || existing.content != content;
      if (!changed && !reembedAll) continue;
      if (changed) {
        _documents[key] = _IndexedZettel(
          id: zettel.id,
          title: zettel.title,
          body: zettel.body,
          content: content,
          termFrequencies: _termFrequencies(zettel.title, zettel.body),
        );
      }
      if (embeddingsReady) {
        try {
          await _embeddingsGateway.upsertDocument(id: key, content: content);
        } catch (_) {
          // Embedding failed for this doc; the keyword index still has it.
        }
      }
    }
    _documents.removeWhere((key, _) => !liveIds.contains(key));
    _wasEmbeddingsReady = embeddingsReady;
    _builtOnce = true;
  }

  static Map<String, int> _termFrequencies(String title, String body) {
    final frequencies = <String, int>{};
    void add(String text, int weight) {
      for (final term in tokenize(text)) {
        frequencies[term] = (frequencies[term] ?? 0) + weight;
      }
    }

    // Title terms weigh double: a title hit is a stronger relevance signal.
    add(title, 2);
    add(body, 1);
    return frequencies;
  }

  Future<bool> _gatewayAvailable() async {
    try {
      return await _embeddingsGateway.isAvailable();
    } catch (_) {
      return false;
    }
  }
}

class _IndexedZettel {
  const _IndexedZettel({
    required this.id,
    required this.title,
    required this.body,
    required this.content,
    required this.termFrequencies,
  });

  final ZettelId id;
  final String title;
  final String body;

  /// `title\nbody` — change-detection key and embedded content.
  final String content;

  final Map<String, int> termFrequencies;
}
