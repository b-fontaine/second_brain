import 'package:equatable/equatable.dart';

/// A note suggested as semantically close to some content — the material of
/// the « Pollinisation » sections and of the « fleur » nodes.
class RelatedNoteSuggestion extends Equatable {
  const RelatedNoteSuggestion({
    required this.id,
    required this.title,
    this.score,
  });

  /// Zettel id of the suggested note.
  final String id;

  /// Title of the suggested note, resolved against the live vault.
  final String title;

  /// Normalized semantic similarity in `[0, 1]` when the embedding index
  /// produced the hit; null in keyword-fallback mode, where only the rank
  /// of the suggestion is meaningful.
  final double? score;

  @override
  List<Object?> get props => [id, title, score];
}
