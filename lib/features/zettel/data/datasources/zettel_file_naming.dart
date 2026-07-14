import 'package:slugify/slugify.dart';

import '../../domain/entities/zettel_id.dart';

/// Maximum length of the slug part of a zettel file name.
const int _maxSlugLength = 60;

/// Builds the vault file name for a zettel: `<id>-<slug>.md`.
///
/// The slug is the lowercased, diacritics-folded, hyphenated title,
/// truncated to [_maxSlugLength] characters. When the title yields no
/// usable slug (e.g. symbols only), the file is named `<id>.md`.
String zettelFileName(ZettelId id, String title) {
  var slug = slugify(title);
  if (slug.length > _maxSlugLength) {
    slug = slug.substring(0, _maxSlugLength);
  }
  slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? '${id.value}.md' : '${id.value}-$slug.md';
}

/// Extracts the zettel id from a vault file name, or returns null when
/// the name does not belong to a zettel file.
///
/// Accepts `<id>-<slug>.md` (our convention), `<id>.md`, and
/// `<id> Title With Spaces.md` (The Archive style) so externally created
/// vaults keep working.
ZettelId? zettelIdFromFileName(String fileName) {
  if (!fileName.toLowerCase().endsWith('.md')) return null;
  final stem = fileName.substring(0, fileName.length - 3);
  final match = RegExp(r'^(\d{14})(?:[-. _]|$)').firstMatch(stem);
  if (match == null) return null;
  return ZettelId.fromString(match.group(1)!);
}
