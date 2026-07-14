import 'package:equatable/equatable.dart';

import 'zettel_id.dart';

/// An atomic note of the Zettelkasten.
///
/// The markdown file in the vault is the source of truth; this entity is
/// its in-memory representation. [body] excludes the YAML frontmatter.
class Zettel extends Equatable {
  const Zettel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.tags = const [],
    this.source,
  });

  final ZettelId id;
  final String title;

  /// Markdown body, frontmatter excluded. May contain `[[id]]` wikilinks.
  final String body;

  final DateTime createdAt;
  final List<String> tags;

  /// Provenance of the note when it came from a capture,
  /// e.g. `capture:audio:meeting.m4a`, `capture:clipboard`.
  final String? source;

  /// Ids referenced by `[[wikilinks]]` found in [body].
  List<ZettelId> get outgoingLinks => parseWikiLinks(body);

  /// Extracts the target ids of all `[[id]]` / `[[id|label]]` wikilinks.
  static List<ZettelId> parseWikiLinks(String markdown) {
    final matches = RegExp(
      r'\[\[(\d{14})(?:\|[^\]]*)?\]\]',
    ).allMatches(markdown);
    final seen = <String>{};
    final ids = <ZettelId>[];
    for (final match in matches) {
      final raw = match.group(1)!;
      if (seen.add(raw)) ids.add(ZettelId.fromString(raw));
    }
    return ids;
  }

  Zettel copyWith({
    String? title,
    String? body,
    List<String>? tags,
    String? source,
  }) {
    return Zettel(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt,
      tags: tags ?? this.tags,
      source: source ?? this.source,
    );
  }

  @override
  List<Object?> get props => [id, title, body, createdAt, tags, source];
}
