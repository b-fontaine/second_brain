import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/usecases/usecase.dart';
import '../../../domain/entities/zettel.dart';
import '../../../domain/repositories/zettel_repository.dart';
import '../../../domain/usecases/get_all_zettels.dart';
import '../../../domain/usecases/search_zettels.dart';

part 'notes_list_event.dart';
part 'notes_list_state.dart';

/// Lists the vault's zettels with live (debounced) search and automatic
/// refresh whenever the vault changes on disk.
@injectable
class NotesListBloc extends Bloc<NotesListEvent, NotesListState> {
  NotesListBloc(
    this._getAllZettels,
    this._searchZettels,
    this._zettelRepository,
  ) : super(const NotesListInitial()) {
    on<NotesListStarted>(_onStarted);
    on<NotesListQueryChanged>(_onQueryChanged);
    on<NotesListVaultChanged>(_onVaultChanged);
    on<_NotesListSearchRequested>(_onSearchRequested);
  }

  /// Delay between the last keystroke and the search execution.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  final GetAllZettels _getAllZettels;
  final SearchZettels _searchZettels;

  /// Injected only for [ZettelRepository.watchVault]; all reads go
  /// through the use cases.
  final ZettelRepository _zettelRepository;

  Timer? _debounceTimer;
  StreamSubscription<VaultChanged>? _vaultSubscription;
  String _query = '';

  Future<void> _onStarted(
    NotesListStarted event,
    Emitter<NotesListState> emit,
  ) async {
    emit(const NotesListLoading());
    _query = '';
    await _vaultSubscription?.cancel();
    _vaultSubscription = _zettelRepository.watchVault().listen((_) {
      if (!isClosed) add(const NotesListVaultChanged());
    });
    final result = await _getAllZettels(const NoParams());
    emit(
      result.fold(
        (failure) => NotesListError(failure.message),
        (zettels) => NotesListLoaded(zettels: zettels, query: ''),
      ),
    );
  }

  void _onQueryChanged(
    NotesListQueryChanged event,
    Emitter<NotesListState> emit,
  ) {
    _query = event.query;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(searchDebounce, () {
      if (!isClosed) add(_NotesListSearchRequested(event.query));
    });
  }

  Future<void> _onSearchRequested(
    _NotesListSearchRequested event,
    Emitter<NotesListState> emit,
  ) async {
    // Ignore requests made stale by a more recent keystroke.
    if (event.query != _query) return;
    final result = await _searchZettels(event.query);
    if (event.query != _query) return;
    emit(
      result.fold(
        (failure) => NotesListError(failure.message),
        (zettels) => NotesListLoaded(zettels: zettels, query: event.query),
      ),
    );
  }

  Future<void> _onVaultChanged(
    NotesListVaultChanged event,
    Emitter<NotesListState> emit,
  ) async {
    final query = _query;
    // SearchZettels falls back to getAllZettels on an empty query.
    final result = await _searchZettels(query);
    if (query != _query) return;
    emit(
      result.fold(
        (failure) => NotesListError(failure.message),
        (zettels) => NotesListLoaded(zettels: zettels, query: query),
      ),
    );
  }

  @override
  Future<void> close() async {
    _debounceTimer?.cancel();
    await _vaultSubscription?.cancel();
    return super.close();
  }
}
