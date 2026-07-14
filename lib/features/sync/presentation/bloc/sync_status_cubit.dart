import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/network_info.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/usecases/force_synchronize.dart';
import '../../domain/usecases/get_sync_status.dart';
import '../../domain/usecases/watch_sync_status.dart';

sealed class SyncStatusState extends Equatable {
  const SyncStatusState();

  @override
  List<Object?> get props => const [];
}

/// Status not loaded yet: the indicator stays hidden.
final class SyncStatusInitial extends SyncStatusState {
  const SyncStatusInitial();
}

/// Current status plus connectivity, ready to display.
final class SyncStatusReady extends SyncStatusState {
  const SyncStatusReady({required this.status, required this.isOnline});

  final SyncStatus status;
  final bool isOnline;

  @override
  List<Object?> get props => [status, isOnline];
}

/// Feeds the AppBar sync indicator: current [SyncStatus] combined with
/// connectivity, and manual synchronization on demand.
@injectable
class SyncStatusCubit extends Cubit<SyncStatusState> {
  SyncStatusCubit(
    this._getSyncStatus,
    this._watchSyncStatus,
    this._forceSynchronize,
    this._networkInfo,
  ) : super(const SyncStatusInitial());

  final GetSyncStatus _getSyncStatus;
  final WatchSyncStatus _watchSyncStatus;
  final ForceSynchronize _forceSynchronize;
  final NetworkInfo _networkInfo;

  StreamSubscription<Either<Failure, SyncStatus>>? _statusSubscription;
  StreamSubscription<bool>? _networkSubscription;
  SyncStatus? _status;
  bool _isOnline = true;

  /// Loads the current status then follows every update.
  Future<void> start() async {
    _isOnline = await _networkInfo.isConnected;

    final initial = await _getSyncStatus(const NoParams());
    initial.fold(
      (failure) => _status = SyncStatus(
        state: SyncState.error,
        message: failure.message,
      ),
      (status) => _status = status,
    );
    _emitReady();

    _statusSubscription = _watchSyncStatus(const NoParams()).listen((either) {
      either.fold((_) {}, (status) {
        _status = status;
        _emitReady();
      });
    });
    _networkSubscription = _networkInfo.onStatusChange.listen((online) {
      _isOnline = online;
      _emitReady();
    });
  }

  /// Manual synchronization (tap on the indicator). Errors surface through
  /// the status stream, nothing to handle here.
  Future<void> forceSync() async {
    final current = state;
    if (current is SyncStatusReady &&
        current.status.state == SyncState.syncing) {
      return;
    }
    await _forceSynchronize(const NoParams());
  }

  void _emitReady() {
    final status = _status;
    if (status == null || isClosed) return;
    emit(SyncStatusReady(status: status, isOnline: _isOnline));
  }

  @override
  Future<void> close() async {
    await _statusSubscription?.cancel();
    await _networkSubscription?.cancel();
    return super.close();
  }
}
