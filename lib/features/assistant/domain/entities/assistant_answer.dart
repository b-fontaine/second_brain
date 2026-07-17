import 'package:equatable/equatable.dart';

import '../../../zettel/domain/entities/zettel_id.dart';

/// A vault note surfaced with an assistant answer: either cited as a
/// source in the answer text, or retrieved as context without being cited
/// (« Et peut-être »).
class AssistantSource extends Equatable {
  const AssistantSource({required this.id, this.title = '', this.linkCount});

  final ZettelId id;

  /// Resolved note title; empty when the note could not be read
  /// (deleted since retrieval, hallucinated id...).
  final String title;

  /// Undirected link degree of the note (drives the maturity badge);
  /// null when the vault could not be read, so the badge is hidden.
  final int? linkCount;

  /// What the UI displays on the chip: the title, or the raw id as a
  /// last resort.
  String get label => title.isEmpty ? id.value : title;

  @override
  List<Object?> get props => [id, title, linkCount];
}

/// Answer of the assistant to a knowledge-base question.
class AssistantAnswer extends Equatable {
  const AssistantAnswer({
    required this.text,
    this.sources = const [],
    this.related = const [],
  });

  /// Markdown answer; may contain `[[id]]` citations.
  final String text;

  /// Notes the answer actually cites, most relevant first. When the model
  /// cited nothing explicitly, the whole retrieved context stands in (the
  /// answer was still built on it).
  final List<AssistantSource> sources;

  /// Notes retrieved as context but not cited in the answer, shown as the
  /// discreet « Et peut-être » suggestions.
  final List<AssistantSource> related;

  @override
  List<Object?> get props => [text, sources, related];
}
