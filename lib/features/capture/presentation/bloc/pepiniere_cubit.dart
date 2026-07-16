import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/services/vault_write_notifier.dart';
// Cross-feature domain imports — documented exception: the nursery reviews
// the pending captures (inbox) owned by the zettel feature and transplants
// them through its use case.
import '../../../zettel/domain/entities/inbox_item.dart';
import '../../../zettel/domain/repositories/inbox_repository.dart';
import '../../../zettel/domain/usecases/transplant_seedling.dart';

/// One-shot feedback surfaced as a SnackBar by the Pépinière page.
///
/// [seq] makes every notice distinct so equatable states re-trigger the
/// listener even when the same message happens twice in a row.
final class PepiniereNotice extends Equatable {
  const PepiniereNotice(this.seq, this.message);

  final int seq;
  final String message;

  @override
  List<Object?> get props => [seq, message];
}

sealed class PepiniereState extends Equatable {
  const PepiniereState();

  @override
  List<Object?> get props => const [];
}

final class PepiniereLoading extends PepiniereState {
  const PepiniereLoading();
}

/// The pending queue could not be read at all (first load).
final class PepiniereLoadFailure extends PepiniereState {
  const PepiniereLoadFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class PepiniereLoaded extends PepiniereState {
  const PepiniereLoaded({required this.items, this.busyItemId, this.notice});

  /// Pending captures, oldest first (FIFO queue of the inbox).
  final List<InboxItem> items;

  /// Item with a transplant/compost in flight; its card actions are
  /// disabled and no concurrent action can start.
  final String? busyItemId;

  /// Feedback of the last finished action, if any.
  final PepiniereNotice? notice;

  @override
  List<Object?> get props => [items, busyItemId, notice];
}

/// Drives the « Pépinière — brouillons à valider » screen: lists the
/// pending captures and carries their two terminal actions, « Repiquer »
/// ([TransplantSeedling]) and « Composter » ([InboxRepository.removeItem]).
///
/// The inbox exposes no stream, but every inbox write pulses
/// [VaultWriteNotifier.changes] (same contract as the Explorer seedling
/// pill); the list is reloaded on each pulse, so a transplant done from the
/// prefilled editor (« Modifier ») refreshes this screen on return too.
@injectable
class PepiniereCubit extends Cubit<PepiniereState> {
  PepiniereCubit(
    this._inboxRepository,
    this._transplantSeedling,
    this._vaultWriteNotifier,
  ) : super(const PepiniereLoading());

  final InboxRepository _inboxRepository;
  final TransplantSeedling _transplantSeedling;
  final VaultWriteNotifier _vaultWriteNotifier;

  StreamSubscription<void>? _subscription;
  int _noticeSeq = 0;

  /// Loads the pending queue, then follows every vault write.
  Future<void> start() async {
    _subscription ??= _vaultWriteNotifier.changes.listen((_) => _reload());
    await _reload();
  }

  /// « Repiquer » : the capture becomes a zettel (enriched proposal as-is)
  /// and leaves the pending queue.
  Future<void> transplant(InboxItem item) async {
    final loaded = _beginAction(item);
    if (loaded == null) return;
    final result = await _transplantSeedling(
      TransplantSeedlingParams(item: item),
    );
    if (isClosed) return;
    result.fold(
      (failure) => _failAction('Le repiquage a échoué : ${failure.message}'),
      (zettel) => _finishAction(
        item,
        'Repiqué au jardin — note « ${zettel.title} » créée.',
      ),
    );
  }

  /// « Composter » : the capture is removed for good. The confirmation
  /// dialog is owned by the page; this method assumes it was accepted.
  Future<void> compost(InboxItem item) async {
    final loaded = _beginAction(item);
    if (loaded == null) return;
    final result = await _inboxRepository.removeItem(item.id);
    if (isClosed) return;
    result.fold(
      (failure) => _failAction('Le compostage a échoué : ${failure.message}'),
      (_) => _finishAction(item, 'Semis composté — brouillon supprimé.'),
    );
  }

  /// Marks [item] busy and returns the current list state, or null when an
  /// action is already in flight (double tap) or the list is not loaded.
  PepiniereLoaded? _beginAction(InboxItem item) {
    final current = state;
    if (current is! PepiniereLoaded || current.busyItemId != null) return null;
    emit(
      PepiniereLoaded(
        items: current.items,
        busyItemId: item.id,
        notice: current.notice,
      ),
    );
    return current;
  }

  void _failAction(String message) {
    final current = state;
    final items = current is PepiniereLoaded ? current.items : <InboxItem>[];
    emit(
      PepiniereLoaded(items: items, busyItemId: null, notice: _notice(message)),
    );
  }

  void _finishAction(InboxItem item, String message) {
    final current = state;
    final items = current is PepiniereLoaded ? current.items : <InboxItem>[];
    emit(
      PepiniereLoaded(
        // Optimistic removal; the vault-write pulse reloads right after
        // and confirms the same list.
        items: [
          for (final other in items)
            if (other.id != item.id) other,
        ],
        busyItemId: null,
        notice: _notice(message),
      ),
    );
  }

  /// A read failure never blanks an already displayed list (offline-first);
  /// only the very first load can surface [PepiniereLoadFailure].
  Future<void> _reload() async {
    final result = await _inboxRepository.getPendingItems();
    if (isClosed) return;
    final current = state;
    result.fold(
      (failure) {
        if (current is! PepiniereLoaded) {
          emit(PepiniereLoadFailure(failure.message));
        }
      },
      (items) => emit(
        PepiniereLoaded(
          items: items,
          // An action may be in flight while a pulse lands: keep its card
          // disabled and do not replay its notice.
          busyItemId: current is PepiniereLoaded ? current.busyItemId : null,
          notice: current is PepiniereLoaded ? current.notice : null,
        ),
      ),
    );
  }

  PepiniereNotice _notice(String message) =>
      PepiniereNotice(++_noticeSeq, message);

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
