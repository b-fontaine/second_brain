part of 'zettel_edit_bloc.dart';

sealed class ZettelEditState extends Equatable {
  const ZettelEditState();

  @override
  List<Object?> get props => const [];
}

final class ZettelEditInitial extends ZettelEditState {
  const ZettelEditInitial();
}

/// Loading the note to edit (edition mode only).
final class ZettelEditLoading extends ZettelEditState {
  const ZettelEditLoading();
}

/// Form ready. [initial] is the note being edited, null when creating.
final class ZettelEditReady extends ZettelEditState {
  const ZettelEditReady({this.initial});

  final Zettel? initial;

  bool get isNew => initial == null;

  @override
  List<Object?> get props => [initial];
}

final class ZettelEditSaving extends ZettelEditState {
  const ZettelEditSaving();
}

final class ZettelEditSaved extends ZettelEditState {
  const ZettelEditSaved(this.zettel);

  final Zettel zettel;

  @override
  List<Object?> get props => [zettel];
}

/// [blocking] is true when the note to edit could not be loaded (the
/// form cannot be shown); false for save/validation errors, which keep
/// the form usable.
final class ZettelEditError extends ZettelEditState {
  const ZettelEditError(this.message, {this.blocking = false});

  final String message;
  final bool blocking;

  @override
  List<Object?> get props => [message, blocking];
}
