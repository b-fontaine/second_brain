part of 'setup_bloc.dart';

sealed class SetupState extends Equatable {
  const SetupState();

  @override
  List<Object?> get props => const [];
}

final class SetupInitial extends SetupState {
  const SetupInitial();
}

/// Input is being validated (also used while preparing a local vault).
final class SetupValidating extends SetupState {
  const SetupValidating();
}

/// The remote repository is being cloned.
final class SetupCloning extends SetupState {
  const SetupCloning({this.progress});

  /// 0..1 clone progress when available, null when indeterminate.
  final double? progress;

  @override
  List<Object?> get props => [progress];
}

final class SetupDone extends SetupState {
  const SetupDone(this.config);

  final VaultConfig config;

  @override
  List<Object?> get props => [config];
}

final class SetupError extends SetupState {
  const SetupError(this.message);

  /// Exact Failure.message, displayed as-is under the form.
  final String message;

  @override
  List<Object?> get props => [message];
}
