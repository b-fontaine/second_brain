part of 'notes_list_bloc.dart';

sealed class NotesListEvent extends Equatable {
  const NotesListEvent();

  @override
  List<Object?> get props => const [];
}

/// Initial load: subscribes to vault changes and fetches all zettels.
final class NotesListStarted extends NotesListEvent {
  const NotesListStarted();
}

/// Search input changed; the search runs after [NotesListBloc.searchDebounce].
final class NotesListQueryChanged extends NotesListEvent {
  const NotesListQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// The vault content changed (save, delete, git pull): refresh the list.
final class NotesListVaultChanged extends NotesListEvent {
  const NotesListVaultChanged();
}

/// Internal: debounced execution of a search.
final class _NotesListSearchRequested extends NotesListEvent {
  const _NotesListSearchRequested(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}
