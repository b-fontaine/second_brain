import 'package:equatable/equatable.dart';

import '../../../zettel/domain/entities/zettel_id.dart';

/// An atomic note proposed by the AI assistant from raw captured content.
///
/// Drafts are always reviewed by the user before becoming zettels.
class ZettelDraft extends Equatable {
  const ZettelDraft({
    required this.title,
    required this.body,
    this.tags = const [],
    this.suggestedLinks = const [],
    this.sourceInboxItemId,
  });

  final String title;

  /// Markdown body; may already contain `[[id]]` wikilinks toward
  /// [suggestedLinks] targets.
  final String body;

  final List<String> tags;

  /// Existing zettels the assistant judged related to this draft.
  final List<ZettelId> suggestedLinks;

  /// Inbox item this draft was derived from, for provenance tracking.
  final String? sourceInboxItemId;

  ZettelDraft copyWith({
    String? title,
    String? body,
    List<String>? tags,
    List<ZettelId>? suggestedLinks,
  }) {
    return ZettelDraft(
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      suggestedLinks: suggestedLinks ?? this.suggestedLinks,
      sourceInboxItemId: sourceInboxItemId,
    );
  }

  @override
  List<Object?> get props => [
    title,
    body,
    tags,
    suggestedLinks,
    sourceInboxItemId,
  ];
}
