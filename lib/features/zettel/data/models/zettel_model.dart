import 'package:yaml/yaml.dart';

import '../../domain/entities/zettel.dart';
import '../../domain/entities/zettel_id.dart';

/// Codec between [Zettel] entities and their markdown file representation.
///
/// File layout (Obsidian/Zettlr compatible):
///
/// ```markdown
/// ---
/// id: "20260714103000"
/// title: "Mémoire de travail"
/// date: 2026-07-14T10:30:00+02:00
/// tags: [cognition, memoire]
/// source: "capture:audio:meeting.m4a"
/// ---
///
/// Body markdown, wikilinks [[20260101120000]] included.
///
/// ## Références
/// - kept verbatim, the codec never rewrites the body.
/// ```
///
/// Frontmatter is written manually with a stable key order
/// (id, title, date, tags, source) so files are deterministic and
/// git-diff friendly. Parsing is done with `package:yaml` on the raw
/// block between `---` delimiters: `front_matter_ml` 1.2.0 crashes on
/// unclosed frontmatter (RangeError) and on non-map YAML (TypeError),
/// so the brief's documented hand-rolled fallback is used instead.
abstract final class ZettelModel {
  static final RegExp _frontMatterPattern = RegExp(
    r'^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|$)',
    dotAll: true,
  );

  static final RegExp _leadingBlankLines = RegExp(r'^(?:[ \t]*\r?\n)+');

  static final RegExp _plainTagPattern = RegExp(
    r'^[A-Za-z0-9_][A-Za-z0-9_-]*$',
  );

  /// Parses a full markdown file (frontmatter + body) into a [Zettel].
  ///
  /// Throws a [FormatException] when the file has no valid frontmatter,
  /// or when a required key (`id`, `title`) is missing or invalid.
  /// A missing/invalid `date` falls back to the timestamp encoded in the id.
  static Zettel fromMarkdown(String raw) {
    var text = raw;
    if (text.startsWith('\uFEFF')) text = text.substring(1);

    final match = _frontMatterPattern.firstMatch(text);
    if (match == null) {
      throw const FormatException('Missing or unclosed YAML frontmatter');
    }

    final Object? data;
    try {
      data = loadYaml(match.group(1)!);
    } on YamlException catch (e) {
      throw FormatException('Invalid YAML frontmatter: ${e.message}');
    }
    if (data is! YamlMap) {
      throw const FormatException('Frontmatter is not a YAML map');
    }

    final rawId = data['id']?.toString().trim();
    if (rawId == null || !ZettelId.isValid(rawId)) {
      throw FormatException('Missing or invalid zettel id: $rawId');
    }
    final id = ZettelId.fromString(rawId);

    final title = data['title']?.toString().trim();
    if (title == null || title.isEmpty) {
      throw const FormatException('Missing zettel title');
    }

    final rawSource = data['source']?.toString().trim();

    return Zettel(
      id: id,
      title: title,
      body: _normalizeBody(text.substring(match.end)),
      createdAt: _parseDate(data['date'], id),
      tags: _parseTags(data['tags']),
      source: (rawSource == null || rawSource.isEmpty) ? null : rawSource,
    );
  }

  /// Serializes [zettel] to its markdown file form.
  ///
  /// Deterministic: same entity in, byte-identical file out. The body is
  /// written verbatim after a blank line; sections such as `## Références`
  /// are therefore preserved untouched.
  static String toMarkdown(Zettel zettel) {
    final z = normalize(zettel);
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('id: "${z.id.value}"')
      ..writeln('title: ${_doubleQuoted(z.title)}')
      ..writeln('date: ${formatIso8601WithOffset(z.createdAt)}')
      ..writeln('tags: [${z.tags.map(_tagScalar).join(', ')}]');
    final source = z.source;
    if (source != null) {
      buffer.writeln('source: ${_doubleQuoted(source)}');
    }
    buffer.writeln('---');
    if (z.body.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(z.body);
    }
    return buffer.toString();
  }

  /// Returns [zettel] in the canonical form the vault stores: trimmed
  /// title/tags/source, body without leading blank lines or trailing
  /// whitespace, creation date at second precision (the vault format
  /// resolution, matching the id).
  static Zettel normalize(Zettel zettel) {
    final source = zettel.source?.trim();
    return Zettel(
      id: zettel.id,
      title: zettel.title.trim(),
      body: _normalizeBody(zettel.body),
      createdAt: truncateToSecond(zettel.createdAt.toLocal()),
      tags: [
        for (final tag in zettel.tags)
          if (tag.trim().isNotEmpty) tag.trim(),
      ],
      source: (source == null || source.isEmpty) ? null : source,
    );
  }

  /// Formats a local datetime as `yyyy-MM-ddTHH:mm:ss±HH:MM`.
  static String formatIso8601WithOffset(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
        '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
        '${two(local.second)}$sign${two(abs.inHours)}:${two(abs.inMinutes % 60)}';
  }

  /// Drops sub-second precision (the vault format stores whole seconds).
  static DateTime truncateToSecond(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
  }

  static String _normalizeBody(String body) =>
      body.replaceFirst(_leadingBlankLines, '').trimRight();

  static DateTime _parseDate(Object? node, ZettelId id) {
    if (node != null) {
      final parsed = DateTime.tryParse(node.toString());
      if (parsed != null) return truncateToSecond(parsed.toLocal());
    }
    // Robust fallback: the id itself encodes the creation timestamp.
    final v = id.value;
    return DateTime(
      int.parse(v.substring(0, 4)),
      int.parse(v.substring(4, 6)),
      int.parse(v.substring(6, 8)),
      int.parse(v.substring(8, 10)),
      int.parse(v.substring(10, 12)),
      int.parse(v.substring(12, 14)),
    );
  }

  static List<String> _parseTags(Object? node) {
    if (node == null) return const [];
    if (node is YamlList) {
      return [
        for (final tag in node)
          if (tag != null && tag.toString().trim().isNotEmpty)
            tag.toString().trim(),
      ];
    }
    final single = node.toString().trim();
    return single.isEmpty ? const [] : [single];
  }

  /// YAML double-quoted scalar with the escapes `package:yaml` understands.
  static String _doubleQuoted(String value) {
    final escaped = value
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return '"$escaped"';
  }

  /// A tag is written as a plain YAML scalar only when re-parsing it
  /// yields the exact same string. Number-like ('007', '0x1A') or
  /// boolean-like ('True') tags would otherwise be resolved as int/bool
  /// by the YAML core schema and silently rewritten on the next
  /// read/write cycle ('007' -> '7'), breaking tag search and filters.
  static String _tagScalar(String tag) =>
      _plainTagPattern.hasMatch(tag) && loadYaml(tag) == tag
      ? tag
      : _doubleQuoted(tag);
}
