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
    this.errorMessage,
  });

  final Zettel zettel;

  /// Notes whose body links to [zettel].
  final List<Zettel> backlinks;

  /// Titles of the notes targeted by the body's wikilinks, keyed by id.
  final Map<String, String> linkTitles;

  /// Transient error (e.g. failed deletion) surfaced without leaving
  /// the loaded state.
  final String? errorMessage;

  ZettelDetailLoaded copyWith({String? errorMessage}) => ZettelDetailLoaded(
    zettel: zettel,
    backlinks: backlinks,
    linkTitles: linkTitles,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [zettel, backlinks, linkTitles, errorMessage];
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
