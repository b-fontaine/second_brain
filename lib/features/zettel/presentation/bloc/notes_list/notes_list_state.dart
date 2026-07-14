part of 'notes_list_bloc.dart';

sealed class NotesListState extends Equatable {
  const NotesListState();

  @override
  List<Object?> get props => const [];
}

final class NotesListInitial extends NotesListState {
  const NotesListInitial();
}

final class NotesListLoading extends NotesListState {
  const NotesListLoading();
}

final class NotesListLoaded extends NotesListState {
  const NotesListLoaded({required this.zettels, this.query = ''});

  final List<Zettel> zettels;

  /// Search query these results correspond to; empty for the full list.
  final String query;

  @override
  List<Object?> get props => [zettels, query];
}

final class NotesListError extends NotesListState {
  const NotesListError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
