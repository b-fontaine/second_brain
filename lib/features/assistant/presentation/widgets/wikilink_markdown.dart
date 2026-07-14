import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/vault_markdown_image.dart';
import '../../../zettel/domain/entities/zettel_id.dart';

/// URI scheme used for pre-transformed `[[id]]` wikilinks.
const zettelLinkScheme = 'zettel:';

final RegExp _wikilinkPattern = RegExp(r'\[\[([^\[\]|]+)(?:\|([^\[\]]+))?\]\]');
final RegExp _leadingIdPattern = RegExp(r'^\d{14}');

/// Rewrites `[[id]]` / `[[id|label]]` wikilinks into standard markdown
/// links (`[label](zettel:id)`) so the markdown renderer makes them
/// tappable. Fenced code blocks are left untouched.
///
/// Same pre-transformation technique as the zettel reading pane.
String transformWikilinksToMarkdownLinks(String source) {
  final parts = source.split('```');
  // Even indexes are outside fenced code blocks.
  for (var i = 0; i < parts.length; i += 2) {
    parts[i] = parts[i].replaceAllMapped(_wikilinkPattern, (match) {
      final target = match.group(1)!.trim();
      final label = match.group(2)?.trim();
      return '[${label ?? target}]($zettelLinkScheme$target)';
    });
  }
  return parts.join('```');
}

/// Extracts the zettel id from a tapped link href, or null when the
/// link does not point to a zettel.
String? zettelIdFromHref(String? href) {
  if (href == null || !href.startsWith(zettelLinkScheme)) return null;
  final target = href.substring(zettelLinkScheme.length);
  if (ZettelId.isValid(target)) return target;
  // Obsidian-style full-filename target: `20260101120000-some-slug`.
  return _leadingIdPattern.firstMatch(target)?.group(0);
}

/// Markdown body whose `[[id]]` citations navigate to `/note/:id`.
class WikilinkMarkdownBody extends StatelessWidget {
  const WikilinkMarkdownBody({super.key, required this.data});

  /// Raw markdown, possibly containing `[[id]]` wikilinks.
  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: transformWikilinksToMarkdownLinks(data),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        a: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
      onTapLink: (text, href, title) {
        final id = zettelIdFromHref(href);
        if (id != null) context.push('/note/$id');
      },
      // Never fetch remote images: assistant answers quote vault content,
      // which comes from the git remote (tracking-beacon risk).
      imageBuilder: vaultMarkdownImageBuilder,
    );
  }
}
