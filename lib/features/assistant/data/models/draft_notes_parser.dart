import 'dart:convert';

import 'package:equatable/equatable.dart';

/// A note as decoded from the LLM JSON output, before it becomes a
/// domain `ZettelDraft` (links and provenance are added by the repository).
class ParsedDraftNote extends Equatable {
  const ParsedDraftNote({
    required this.title,
    required this.body,
    this.tags = const [],
  });

  final String title;
  final String body;
  final List<String> tags;

  @override
  List<Object?> get props => [title, body, tags];
}

/// Robust parser for the assistant's draft-splitting JSON output.
///
/// Expected shape: `{"notes":[{"title","body","tags":[...]}]}` — but local
/// models routinely wrap it in prose or markdown fences and leave trailing
/// commas, so the parser extracts the first balanced JSON object and repairs
/// trailing commas before giving up.
class DraftNotesParser {
  const DraftNotesParser._();

  /// Returns the decoded notes, or null when nothing usable was recovered
  /// (caller then retries with a correction prompt or falls back).
  static List<ParsedDraftNote>? tryParse(String raw) {
    final jsonText = extractFirstJsonObject(raw);
    if (jsonText == null) return null;

    final decoded =
        _tryDecode(jsonText) ?? _tryDecode(repairTrailingCommas(jsonText));
    if (decoded is! Map) return null;

    final notes = decoded['notes'];
    if (notes is! List) return null;

    final parsed = <ParsedDraftNote>[];
    for (final note in notes) {
      if (note is! Map) continue;
      final title = note['title'];
      final body = note['body'];
      if (title is! String || body is! String) continue;
      if (title.trim().isEmpty || body.trim().isEmpty) continue;
      final rawTags = note['tags'];
      final tags = <String>[
        if (rawTags is List)
          for (final tag in rawTags)
            if (tag is String && tag.trim().isNotEmpty) tag.trim(),
      ];
      parsed.add(
        ParsedDraftNote(title: title.trim(), body: body.trim(), tags: tags),
      );
    }
    return parsed.isEmpty ? null : parsed;
  }

  /// Extracts the first balanced `{...}` block, ignoring braces inside JSON
  /// strings. Markdown fences and surrounding prose are skipped naturally.
  /// When the object is unbalanced (truncated output), returns a best-effort
  /// slice up to the last closing brace.
  static String? extractFirstJsonObject(String raw) {
    final start = raw.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < raw.length; i++) {
      final char = raw[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return raw.substring(start, i + 1);
      }
    }
    final lastBrace = raw.lastIndexOf('}');
    return lastBrace > start ? raw.substring(start, lastBrace + 1) : null;
  }

  /// Removes trailing commas before `}` or `]` — the most common local-LLM
  /// JSON defect. String-aware (same state machine as
  /// [extractFirstJsonObject]): commas inside JSON string values are never
  /// touched, so note bodies like `"points : [1, 2, ]"` survive intact.
  /// Best effort: only used after a strict decode failed.
  static String repairTrailingCommas(String jsonText) {
    final buffer = StringBuffer();
    var inString = false;
    var escaped = false;
    for (var i = 0; i < jsonText.length; i++) {
      final char = jsonText[i];
      if (inString) {
        buffer.write(char);
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == ',') {
        // Look ahead past whitespace: a comma directly before a closing
        // bracket is a structural trailing comma and gets dropped.
        var next = i + 1;
        while (next < jsonText.length && _isJsonWhitespace(jsonText[next])) {
          next++;
        }
        if (next < jsonText.length &&
            (jsonText[next] == '}' || jsonText[next] == ']')) {
          continue;
        }
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  static bool _isJsonWhitespace(String char) =>
      char == ' ' || char == '\t' || char == '\n' || char == '\r';

  static Object? _tryDecode(String jsonText) {
    try {
      return jsonDecode(jsonText);
    } on FormatException {
      return null;
    }
  }
}
