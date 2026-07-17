import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/serre_tokens.dart';

/// Kind of a [MarkdownSegment].
enum MarkdownSegmentKind { plain, heading, bold, wikilink }

/// A run of text with a single markdown role, as produced by
/// [MarkdownHighlightingController.segment].
class MarkdownSegment extends Equatable {
  const MarkdownSegment(this.kind, this.text);

  final MarkdownSegmentKind kind;
  final String text;

  @override
  List<Object?> get props => [kind, text];
}

/// Drop-in [TextEditingController] adding a light markdown coloring to the
/// note body editor: `# headings` (bold, accent), `**bold**` (bold) and
/// `[[wikilinks]]` (accent).
///
/// Deliberately NOT a markdown parser: a single combined regex, one linear
/// pass over the text per rebuild — no quadratic work on long notes. The
/// IME composing-region underline is not reproduced (the coloring replaces
/// the default span construction).
class MarkdownHighlightingController extends TextEditingController {
  MarkdownHighlightingController({super.text});

  /// One alternation per style, matched in a single linear pass. Order
  /// matters: a heading line wins over anything it contains.
  static final RegExp _pattern = RegExp(
    r'(^#{1,6}[ \t][^\n]*)'
    r'|(\*\*(?:[^*\n]|\*(?!\*))+\*\*)'
    r'|(\[\[[^\[\]\n]+\]\])',
    multiLine: true,
  );

  /// Splits [text] into styled segments. Pure and deterministic — exposed
  /// for unit tests.
  static List<MarkdownSegment> segment(String text) {
    if (text.isEmpty) return const [];
    final segments = <MarkdownSegment>[];
    var cursor = 0;
    for (final match in _pattern.allMatches(text)) {
      if (match.start > cursor) {
        segments.add(
          MarkdownSegment(
            MarkdownSegmentKind.plain,
            text.substring(cursor, match.start),
          ),
        );
      }
      final kind = match.group(1) != null
          ? MarkdownSegmentKind.heading
          : match.group(2) != null
          ? MarkdownSegmentKind.bold
          : MarkdownSegmentKind.wikilink;
      segments.add(MarkdownSegment(kind, match.group(0)!));
      cursor = match.end;
    }
    if (cursor < text.length) {
      segments.add(
        MarkdownSegment(MarkdownSegmentKind.plain, text.substring(cursor)),
      );
    }
    return segments;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) return TextSpan(style: style, text: text);
    final theme = Theme.of(context);
    final accent =
        theme.extension<SerreTokens>()?.accent ?? theme.colorScheme.primary;
    final headingStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: accent,
    );
    const boldStyle = TextStyle(fontWeight: FontWeight.w700);
    final wikilinkStyle = TextStyle(color: accent);
    return TextSpan(
      style: style,
      children: [
        for (final segment in segment(text))
          TextSpan(
            text: segment.text,
            style: switch (segment.kind) {
              MarkdownSegmentKind.plain => null,
              MarkdownSegmentKind.heading => headingStyle,
              MarkdownSegmentKind.bold => boldStyle,
              MarkdownSegmentKind.wikilink => wikilinkStyle,
            },
          ),
      ],
    );
  }
}
