import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/services/vault_write_notifier.dart';
// Cross-feature domain import — documented exception: the Explorer surface
// surfaces the pending-capture count of the « pépinière » (inbox), whose
// repository is owned by the zettel feature.
import '../../../zettel/domain/repositories/inbox_repository.dart';

/// Counts the pending captures awaiting review in the « pépinière »
/// (`inbox/` folder). Feeds the « n semis » pill of the Explorer surface.
///
/// The inbox repository exposes no stream, but every inbox write pulses
/// [VaultWriteNotifier.changes]; the count is reloaded on each pulse.
@injectable
class SeedlingCountCubit extends Cubit<int> {
  SeedlingCountCubit(this._inboxRepository, this._vaultWriteNotifier)
    : super(0);

  final InboxRepository _inboxRepository;
  final VaultWriteNotifier _vaultWriteNotifier;

  StreamSubscription<void>? _subscription;

  /// Loads the current count, then follows every vault write.
  Future<void> start() async {
    _subscription ??= _vaultWriteNotifier.changes.listen((_) => _reload());
    await _reload();
  }

  /// A read failure keeps the last known count (offline-first: a transient
  /// error must never blank the pill).
  Future<void> _reload() async {
    final result = await _inboxRepository.getPendingItems();
    if (isClosed) return;
    result.fold((_) {}, (items) => emit(items.length));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
