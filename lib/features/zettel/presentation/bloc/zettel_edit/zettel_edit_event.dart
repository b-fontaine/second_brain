part of 'zettel_edit_bloc.dart';

sealed class ZettelEditEvent extends Equatable {
  const ZettelEditEvent();

  @override
  List<Object?> get props => const [];
}

/// Opens the editor: transplant mode when [draftItem] is set (nursery
/// « Modifier »), creation when [id] is also null, edition otherwise.
final class ZettelEditStarted extends ZettelEditEvent {
  const ZettelEditStarted({this.id, this.draftItem})
    : assert(
        id == null || draftItem == null,
        'A note edition and a nursery draft are exclusive',
      );

  final ZettelId? id;

  /// Pending capture prefilled in the form; its submission transplants it
  /// into a zettel instead of creating a bare note.
  final InboxItem? draftItem;

  @override
  List<Object?> get props => [id, draftItem];
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
