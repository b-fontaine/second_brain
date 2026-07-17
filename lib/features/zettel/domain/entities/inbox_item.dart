import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

/// Origin of a captured piece of content.
enum CaptureType {
  clipboard,
  audio,
  screenshot,
  dictation,

  /// Text/markdown file imported from disk (« Ajouter un fichier »).
  file,

  /// Assistant synthesis sown from the chat (« Semer cette synthèse »).
  assistant,
}

/// Lifecycle of an inbox item: captured, then processed into zettels
/// (or discarded).
enum InboxStatus { pending, processed, discarded }

/// A raw capture waiting to be processed into atomic zettels.
///
/// Persisted in the vault's `inbox/` folder so no capture is ever lost,
/// even if the AI assistant is unavailable.
class InboxItem extends Equatable {
  const InboxItem({
    required this.id,
    required this.type,
    required this.rawText,
    required this.capturedAt,
    this.assetPath,
    this.title,
    this.tags = const [],
    this.status = InboxStatus.pending,
  });

  /// Unique id (timestamp-based, same convention as zettel ids but
  /// belonging to the inbox namespace).
  final String id;

  final CaptureType type;

  /// Extracted text: clipboard content, transcript, or OCR output.
  final String rawText;

  final DateTime capturedAt;

  /// Relative vault path of the original asset (audio file, image),
  /// when the capture had one.
  final String? assetPath;

  /// Proposed title of the enriched draft (seeding intake); null for
  /// captures made before enrichment existed or saved without one.
  final String? title;

  /// Proposed parcelles (tags) of the enriched draft.
  final List<String> tags;

  final InboxStatus status;

  static const int _proposedTitleMaxChars = 80;

  /// Fallback title of drafts saved without one (before enrichment
  /// existed, or when the local model was unavailable).
  static const String untitledSeedling = 'Semis sans titre';

  /// Title shown for this draft in the nursery (« Pépinière ») and used
  /// when it is transplanted into a zettel: the enriched [title] when
  /// present, otherwise the first non-empty line of [rawText] (markdown
  /// heading marks stripped, truncated), or [untitledSeedling].
  String get proposedTitle {
    final explicit = title?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    for (final line in rawText.split('\n')) {
      final stripped = line.trim().replaceFirst(RegExp(r'^#+\s*'), '').trim();
      if (stripped.isEmpty) continue;
      if (stripped.length <= _proposedTitleMaxChars) return stripped;
      return '${stripped.substring(0, _proposedTitleMaxChars).trimRight()}…';
    }
    return untitledSeedling;
  }

  /// Provenance recorded on the zettel created from this capture:
  /// `capture:<type>:<ref>` where ref is the asset file name when the
  /// capture had one (e.g. `capture:audio:meeting.m4a`), otherwise the
  /// inbox item id. Single source of truth for every transplanting path.
  String get captureSource {
    final asset = assetPath;
    final ref = (asset == null || asset.isEmpty) ? id : p.basename(asset);
    return 'capture:${type.name}:$ref';
  }

  InboxItem copyWith({
    InboxStatus? status,
    String? rawText,
    String? title,
    List<String>? tags,
  }) {
    return InboxItem(
      id: id,
      type: type,
      rawText: rawText ?? this.rawText,
      capturedAt: capturedAt,
      assetPath: assetPath,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    rawText,
    capturedAt,
    assetPath,
    title,
    tags,
    status,
  ];
}
