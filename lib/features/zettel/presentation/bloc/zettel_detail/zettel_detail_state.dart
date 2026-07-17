part of 'zettel_detail_cubit.dart';

sealed class ZettelDetailState extends Equatable {
  const ZettelDetailState();

  @override
  List<Object?> get props => const [];
}

final class ZettelDetailInitial extends ZettelDetailState {
  const ZettelDetailInitial();
}

final class ZettelDetailLoading extends ZettelDetailState {
  const ZettelDetailLoading();
}

final class ZettelDetailLoaded extends ZettelDetailState {
  const ZettelDetailLoaded({
    required this.zettel,
    this.backlinks = const [],
    this.linkTitles = const {},
    this.degrees = const {},
    this.suggestions = const [],
    this.errorMessage,
  });

  final Zettel zettel;

  /// Notes whose body links to [zettel].
  final List<Zettel> backlinks;

  /// Titles of the notes targeted by the body's wikilinks, keyed by id.
  final Map<String, String> linkTitles;

  /// Undirected link count of the note and of each 1-hop neighbor, keyed by
  /// zettel id — drives the maturity pastilles and the mini-constellation.
  final Map<String, int> degrees;

  /// « Pollinisation » : notes semantically close but not linked yet,
  /// best first. Empty until the local index answers (and on index errors).
  final List<RelatedNoteSuggestion> suggestions;

  /// Transient error (e.g. failed deletion or weave) surfaced without
  /// leaving the loaded state.
  final String? errorMessage;

  /// Copy keeping everything but the given fields. [errorMessage] is
  /// deliberately NOT carried over when omitted: it is transient.
  ZettelDetailLoaded copyWith({
    List<RelatedNoteSuggestion>? suggestions,
    String? errorMessage,
  }) => ZettelDetailLoaded(
    zettel: zettel,
    backlinks: backlinks,
    linkTitles: linkTitles,
    degrees: degrees,
    suggestions: suggestions ?? this.suggestions,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [
    zettel,
    backlinks,
    linkTitles,
    degrees,
    suggestions,
    errorMessage,
  ];
}

final class ZettelDetailDeleted extends ZettelDetailState {
  const ZettelDetailDeleted();
}

final class ZettelDetailError extends ZettelDetailState {
  const ZettelDetailError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
