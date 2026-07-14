part of 'settings_cubit.dart';

sealed class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => const [];
}

/// Configuration being read; the screen shows a spinner.
final class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

/// The configuration itself could not be read (full-screen error).
final class SettingsError extends SettingsState {
  const SettingsError(this.message);

  /// Exact Failure.message, displayed as-is.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Configuration displayed. The token action sub-states below extend this
/// so the form stays visible while a test or a save is running.
class SettingsLoaded extends SettingsState {
  const SettingsLoaded({
    required this.remoteUrl,
    required this.hasStoredToken,
    this.syncStatus,
  });

  /// HTTPS url of the remote repository; null when the vault is
  /// local-only (token management is then hidden).
  final String? remoteUrl;

  /// Whether a token is stored, without ever exposing its value.
  final bool hasStoredToken;

  /// Current synchronization status, null when unavailable.
  final SyncStatus? syncStatus;

  bool get hasRemote => remoteUrl != null && remoteUrl!.isNotEmpty;

  @override
  List<Object?> get props => [remoteUrl, hasStoredToken, syncStatus];
}

/// A connection test is running.
final class SettingsTesting extends SettingsLoaded {
  SettingsTesting.of(SettingsLoaded s)
    : super(
        remoteUrl: s.remoteUrl,
        hasStoredToken: s.hasStoredToken,
        syncStatus: s.syncStatus,
      );
}

/// The remote accepted the token («Connexion au dépôt réussie»).
final class SettingsTestSuccess extends SettingsLoaded {
  SettingsTestSuccess.of(SettingsLoaded s)
    : super(
        remoteUrl: s.remoteUrl,
        hasStoredToken: s.hasStoredToken,
        syncStatus: s.syncStatus,
      );
}

/// The connection test failed; [message] is the Failure message.
final class SettingsTestFailure extends SettingsLoaded {
  SettingsTestFailure.of(SettingsLoaded s, this.message)
    : super(
        remoteUrl: s.remoteUrl,
        hasStoredToken: s.hasStoredToken,
        syncStatus: s.syncStatus,
      );

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

/// The token is being tested and persisted.
final class SettingsSaving extends SettingsLoaded {
  SettingsSaving.of(SettingsLoaded s)
    : super(
        remoteUrl: s.remoteUrl,
        hasStoredToken: s.hasStoredToken,
        syncStatus: s.syncStatus,
      );
}

/// The token was tested and persisted («Jeton mis à jour»).
final class SettingsSaved extends SettingsLoaded {
  SettingsSaved.of(SettingsLoaded s)
    : super(
        remoteUrl: s.remoteUrl,
        // Saving succeeded, so a token is now stored by construction.
        hasStoredToken: true,
        syncStatus: s.syncStatus,
      );
}

/// The save failed (test rejected or storage error); nothing persisted.
final class SettingsSaveFailure extends SettingsLoaded {
  SettingsSaveFailure.of(SettingsLoaded s, this.message)
    : super(
        remoteUrl: s.remoteUrl,
        hasStoredToken: s.hasStoredToken,
        syncStatus: s.syncStatus,
      );

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}
