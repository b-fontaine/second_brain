import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../setup/domain/usecases/get_vault_config.dart';
// Cross-feature import — documented exception: the « Jardin » card of the
// settings shows a simple vault statistic (note count) read through the
// zettel domain use case.
import '../../../zettel/domain/usecases/get_all_zettels.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/repositories/git_sync_repository.dart';
import '../../domain/usecases/force_synchronize.dart';
import '../../domain/usecases/get_sync_status.dart';
import '../../domain/usecases/test_remote_connection.dart';
import '../../domain/usecases/update_git_token.dart';

part 'settings_state.dart';

/// Drives the settings screen: vault/remote overview, git access token
/// renewal (test + atomic save) and manual synchronization.
///
/// Lives in the sync feature because everything it manages (token,
/// connection test, sync status) belongs to the sync domain; only the
/// read-only vault configuration comes from the setup feature.
@injectable
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(
    this._getVaultConfig,
    this._getSyncStatus,
    this._testRemoteConnection,
    this._updateGitToken,
    this._forceSynchronize,
    this._repository,
    this._getAllZettels,
  ) : super(const SettingsLoading());

  final GetVaultConfig _getVaultConfig;
  final GetSyncStatus _getSyncStatus;
  final TestRemoteConnection _testRemoteConnection;
  final UpdateGitToken _updateGitToken;
  final ForceSynchronize _forceSynchronize;
  final GitSyncRepository _repository;
  final GetAllZettels _getAllZettels;

  /// Reads the vault configuration, the token presence flag (never the
  /// token itself) and the current sync status.
  Future<void> load() async {
    emit(const SettingsLoading());
    final configResult = await _getVaultConfig(const NoParams());
    await configResult.fold(
      (failure) async => emit(SettingsError(failure.message)),
      (config) async {
        final hasToken = (await _repository.hasStoredToken()).getOrElse(
          (_) => false,
        );
        final status = (await _getSyncStatus(const NoParams())).fold(
          (_) => null,
          (status) => status,
        );
        // Simple garden statistic; unavailable (null) when the vault
        // cannot be read — the card then hides the count.
        final noteCount = (await _getAllZettels(const NoParams())).fold<int?>(
          (_) => null,
          (zettels) => zettels.length,
        );
        if (isClosed) return;
        emit(
          SettingsLoaded(
            remoteUrl: config?.remoteUrl,
            hasStoredToken: hasToken,
            syncStatus: status,
            vaultPath: config?.vaultPath,
            noteCount: noteCount,
          ),
        );
      },
    );
  }

  /// Tests the remote connection with [candidateToken] when non-blank,
  /// with the stored token otherwise. Nothing is persisted.
  Future<void> testConnection(String candidateToken) async {
    final current = state;
    if (current is! SettingsLoaded || _isBusy(current)) return;
    emit(SettingsTesting.of(current));
    final trimmed = candidateToken.trim();
    final result = await _testRemoteConnection(
      TestRemoteConnectionParams(
        tokenOverride: trimmed.isEmpty ? null : trimmed,
      ),
    );
    if (isClosed) return;
    result.fold(
      (failure) => emit(SettingsTestFailure.of(current, failure.message)),
      (_) => emit(SettingsTestSuccess.of(current)),
    );
  }

  /// Atomically tests then persists [token]; a failed test persists
  /// nothing (see [UpdateGitToken]).
  Future<void> saveToken(String token) async {
    final current = state;
    if (current is! SettingsLoaded || _isBusy(current)) return;
    emit(SettingsSaving.of(current));
    final result = await _updateGitToken(UpdateGitTokenParams(token));
    if (isClosed) return;
    result.fold(
      (failure) => emit(SettingsSaveFailure.of(current, failure.message)),
      (_) => emit(SettingsSaved.of(current)),
    );
  }

  /// Manual synchronization, then refreshes the displayed status (errors
  /// surface through the status itself).
  Future<void> forceSync() async {
    final current = state;
    if (current is! SettingsLoaded || _isBusy(current)) return;
    await _forceSynchronize(const NoParams());
    final status = (await _getSyncStatus(const NoParams())).fold(
      (_) => current.syncStatus,
      (status) => status,
    );
    if (isClosed) return;
    emit(
      SettingsLoaded(
        remoteUrl: current.remoteUrl,
        hasStoredToken: current.hasStoredToken,
        syncStatus: status,
        vaultPath: current.vaultPath,
        noteCount: current.noteCount,
      ),
    );
  }

  bool _isBusy(SettingsLoaded state) =>
      state is SettingsTesting || state is SettingsSaving;
}
