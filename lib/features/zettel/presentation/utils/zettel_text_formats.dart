import 'wikilink_markdown.dart';

const List<String> _shortMonthsFr = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

const List<String> _fullMonthsFr = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Short French relative date for list items:
/// "à l'instant", "il y a 5 min", "il y a 3 h", "hier", "il y a 4 j",
/// then "12 juil." (current year) or "12 juil. 2025".
String formatRelativeDateFr(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final local = date.toLocal();
  final dayDiff = _dateOnly(reference).difference(_dateOnly(local)).inDays;
  if (dayDiff < 0) {
    // Future date (clock skew): fall back to the absolute date.
    return _formatShortDateFr(local, withYear: local.year != reference.year);
  }
  if (dayDiff == 0) {
    final diff = reference.difference(local);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    return 'il y a ${diff.inHours} h';
  }
  if (dayDiff == 1) return 'hier';
  if (dayDiff < 7) return 'il y a $dayDiff j';
  return _formatShortDateFr(local, withYear: local.year != reference.year);
}

/// Full French date with time, e.g. "14 juillet 2026 à 10:30".
String formatFullDateFr(DateTime date) {
  final local = date.toLocal();
  final day = local.day == 1 ? '1er' : '${local.day}';
  final minutes = local.minute.toString().padLeft(2, '0');
  return '$day ${_fullMonthsFr[local.month - 1]} ${local.year} '
      'à ${local.hour}:$minutes';
}

/// French month-year label for chronological group headers,
/// e.g. "juillet 2026".
String formatMonthYearFr(DateTime date) {
  final local = date.toLocal();
  return '${_fullMonthsFr[local.month - 1]} ${local.year}';
}

String _formatShortDateFr(DateTime date, {required bool withYear}) {
  final day = date.day == 1 ? '1er' : '${date.day}';
  final base = '$day ${_shortMonthsFr[date.month - 1]}';
  return withYear ? '$base ${date.year}' : base;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Plain-text excerpt of a markdown body, for two-line list previews.
/// Strips code blocks, markdown markers, links and wikilinks.
String zettelExcerpt(String body) {
  var text = body;
  text = text.replaceAll(RegExp(r'```[\s\S]*?(```|$)'), ' ');
  text = text.replaceAll(RegExp(r'~~~[\s\S]*?(~~~|$)'), ' ');
  text = text.replaceAllMapped(wikiLinkPattern, (match) {
    final alias = match.group(2)?.trim();
    if (alias != null && alias.isNotEmpty) return alias;
    return match.group(1)!.trim();
  });
  // Images then regular links: keep the alt/label text only.
  text = text.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );
  final lines = text.split('\n').map((line) {
    var l = line.trim();
    l = l.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
    l = l.replaceFirst(RegExp(r'^>\s?'), '');
    l = l.replaceFirst(RegExp(r'^[-*+]\s+'), '');
    l = l.replaceFirst(RegExp(r'^\d+\.\s+'), '');
    return l;
  });
  var joined = lines.join(' ');
  joined = joined.replaceAll(RegExp(r'[*_`~]'), '');
  return joined.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Removes a leading `# Heading` that merely duplicates the note title
/// (files may carry the title as an H1 for tool independence).
String stripLeadingTitleHeading(String body, String title) {
  final lines = body.split('\n');
  var i = 0;
  while (i < lines.length && lines[i].trim().isEmpty) {
    i++;
  }
  if (i < lines.length) {
    final match = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(lines[i].trim());
    if (match != null &&
        match.group(1)!.trim().toLowerCase() == title.trim().toLowerCase()) {
      return lines.sublist(i + 1).join('\n');
    }
  }
  return body;
}

/// Normalizes a user-typed tag: lowercase, trimmed, leading `#` removed,
/// inner whitespace collapsed to hyphens (vault convention).
String normalizeTag(String raw) {
  var tag = raw.trim().toLowerCase();
  if (tag.startsWith('#')) tag = tag.substring(1);
  tag = tag.replaceAll(RegExp(r'\s+'), '-');
  return tag;
}
