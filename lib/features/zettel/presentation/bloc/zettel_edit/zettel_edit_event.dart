part of 'zettel_edit_bloc.dart';

sealed class ZettelEditEvent extends Equatable {
  const ZettelEditEvent();

  @override
  List<Object?> get props => const [];
}

/// Opens the editor: creation when [id] is null, edition otherwise.
final class ZettelEditStarted extends ZettelEditEvent {
  const ZettelEditStarted({this.id});

  final ZettelId? id;

  @override
  List<Object?> get props => [id];
}

/// Save request carrying the current form values.
final class ZettelEditSubmitted extends ZettelEditEvent {
  const ZettelEditSubmitted({
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
