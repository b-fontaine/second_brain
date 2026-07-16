import 'dart:convert';

import '../../domain/entities/inbox_item.dart';

/// Codec between [InboxItem] entities and their JSON file representation.
///
/// Inbox items are simple `<id>.json` files in the vault's `inbox/`
/// folder — no frontmatter, just a flat JSON object. Deterministic key
/// order and pretty-printing keep the files git-diff friendly.
abstract final class InboxItemModel {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Parses the content of an `inbox/<id>.json` file.
  ///
  /// Throws a [FormatException] when the payload is not a JSON object
  /// or when a required field is missing or malformed.
  static InboxItem fromJsonString(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Inbox item is not a JSON object');
    }
    return fromJson(decoded);
  }

  /// Builds an [InboxItem] from a decoded JSON map.
  static InboxItem fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Missing inbox item id');
    }

    final rawText = json['rawText'];
    if (rawText is! String) {
      throw const FormatException('Missing inbox item rawText');
    }

    final capturedAtRaw = json['capturedAt'];
    if (capturedAtRaw is! String) {
      throw const FormatException('Missing inbox item capturedAt');
    }
    final capturedAt = DateTime.tryParse(capturedAtRaw);
    if (capturedAt == null) {
      throw FormatException('Invalid capturedAt: $capturedAtRaw');
    }

    final assetPath = json['assetPath'];

    // Enrichment fields are lenient: inbox files written before the
    // seeding intake existed simply have no title and no tags.
    final title = json['title'];
    final rawTags = json['tags'];
    final tags = <String>[
      if (rawTags is List)
        for (final tag in rawTags)
          if (tag is String && tag.trim().isNotEmpty) tag.trim(),
    ];

    return InboxItem(
      id: id,
      type: _enumByName(CaptureType.values, json['type'], 'type'),
      rawText: rawText,
      capturedAt: capturedAt,
      assetPath: assetPath is String && assetPath.isNotEmpty ? assetPath : null,
      title: title is String && title.trim().isNotEmpty ? title.trim() : null,
      tags: tags,
      status: _enumByName(InboxStatus.values, json['status'], 'status'),
    );
  }

  /// Serializes [item] to a JSON map with a stable key order.
  static Map<String, dynamic> toJson(InboxItem item) => <String, dynamic>{
    'id': item.id,
    'type': item.type.name,
    'rawText': item.rawText,
    'capturedAt': item.capturedAt.toIso8601String(),
    if (item.assetPath != null) 'assetPath': item.assetPath,
    if (item.title != null) 'title': item.title,
    if (item.tags.isNotEmpty) 'tags': item.tags,
    'status': item.status.name,
  };

  /// Serializes [item] to the pretty-printed file content.
  static String toJsonString(InboxItem item) =>
      '${_encoder.convert(toJson(item))}\n';

  static T _enumByName<T extends Enum>(
    List<T> values,
    Object? raw,
    String key,
  ) {
    final match = values.asNameMap()[raw?.toString()];
    if (match == null) {
      throw FormatException('Invalid inbox item $key: $raw');
    }
    return match;
  }
}
