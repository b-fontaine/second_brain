import '../../domain/entities/zettel_id.dart';

/// Custom URI scheme used to encode wikilinks as regular markdown links
/// so they can be intercepted in `onTapLink`.
const String wikiLinkScheme = 'sb';

/// Prefix of the href produced for a wikilink, e.g. `sb://note/20260714103000`.
const String wikiLinkPrefix = '$wikiLinkScheme://note/';

/// Matches `[[target]]` and `[[target|alias]]`.
/// Group 1 = target (id or filename), group 2 = optional alias.
final RegExp wikiLinkPattern = RegExp(r'\[\[([^\[\]|]+)(?:\|([^\[\]]+))?\]\]');

final RegExp _idPrefixPattern = RegExp(r'^\d{14}');

/// Rewrites `[[id]]` / `[[id|label]]` wikilinks into standard markdown links
/// `[label](sb://note/id)` so `flutter_markdown_plus` renders them tappable.
///
/// - The label is the alias when present, otherwise the target note title
///   from [titlesById], otherwise the raw id.
/// - Targets written as full filenames (`[[<id>-<slug>]]`, Obsidian style)
///   are resolved by their 14-digit id prefix.
/// - Targets with no valid id are rendered as plain text (unresolved link).
/// - Wikilinks inside fenced code blocks or inline code are left untouched.
String transformWikilinks(
  String markdown, {
  Map<String, String> titlesById = const {},
}) {
  final lines = markdown.split('\n');
  final out = <String>[];
  var inFence = false;
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inFence = !inFence;
      out.add(line);
      continue;
    }
    out.add(inFence ? line : _transformOutsideInlineCode(line, titlesById));
  }
  return out.join('\n');
}

/// Extracts the zettel id from an href produced by [transformWikilinks],
/// or returns null if [href] is not a wikilink href.
String? zettelIdFromWikiHref(String? href) {
  if (href == null || !href.startsWith(wikiLinkPrefix)) return null;
  final id = href.substring(wikiLinkPrefix.length);
  return ZettelId.isValid(id) ? id : null;
}

String _transformOutsideInlineCode(
  String line,
  Map<String, String> titlesById,
) {
  // Segments at even indexes are outside inline code spans.
  final parts = line.split('`');
  for (var i = 0; i < parts.length; i += 2) {
    parts[i] = _replaceWikilinks(parts[i], titlesById);
  }
  return parts.join('`');
}

String _replaceWikilinks(String text, Map<String, String> titlesById) {
  return text.replaceAllMapped(wikiLinkPattern, (match) {
    final target = match.group(1)!.trim();
    final alias = match.group(2)?.trim();
    final idMatch = _idPrefixPattern.firstMatch(target);
    if (idMatch == null) {
      // No resolvable id: keep the human-readable part as plain text.
      return (alias != null && alias.isNotEmpty) ? alias : target;
    }
    final id = idMatch.group(0)!;
    final label = (alias != null && alias.isNotEmpty)
        ? alias
        : (titlesById[id] ?? id);
    return '[${_escapeLabel(label)}]($wikiLinkPrefix$id)';
  });
}

String _escapeLabel(String label) =>
    label.replaceAll('[', r'\[').replaceAll(']', r'\]');
