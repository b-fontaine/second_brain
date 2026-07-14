part of 'setup_bloc.dart';

sealed class SetupEvent extends Equatable {
  const SetupEvent();

  @override
  List<Object?> get props => const [];
}

/// The user submitted the remote repository form.
final class SetupRemoteSubmitted extends SetupEvent {
  const SetupRemoteSubmitted({required this.remoteUrl, required this.token});

  final String remoteUrl;
  final String token;

  @override
  List<Object?> get props => [remoteUrl, token];
}

/// The user chose to continue without synchronization.
final class SetupLocalOnlyRequested extends SetupEvent {
  const SetupLocalOnlyRequested();
}
