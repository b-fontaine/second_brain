import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/vault_config.dart';
import '../../domain/usecases/configure_local_only.dart';
import '../../domain/usecases/configure_with_remote.dart';
import '../../domain/usecases/git_remote_url_validator.dart';

part 'setup_event.dart';
part 'setup_state.dart';

/// Drives the first-run onboarding: remote clone or local-only vault.
@injectable
class SetupBloc extends Bloc<SetupEvent, SetupState> {
  SetupBloc(this._configureWithRemote, this._configureLocalOnly)
    : super(const SetupInitial()) {
    on<SetupRemoteSubmitted>(_onRemoteSubmitted);
    on<SetupLocalOnlyRequested>(_onLocalOnlyRequested);
  }

  final ConfigureWithRemote _configureWithRemote;
  final ConfigureLocalOnly _configureLocalOnly;

  Future<void> _onRemoteSubmitted(
    SetupRemoteSubmitted event,
    Emitter<SetupState> emit,
  ) async {
    emit(const SetupValidating());
    final remoteUrl = event.remoteUrl.trim();
    if (!GitRemoteUrlValidator.isValid(remoteUrl)) {
      emit(const SetupError(GitRemoteUrlValidator.invalidUrlMessage));
      return;
    }
    emit(const SetupCloning());
    final result = await _configureWithRemote(
      ConfigureWithRemoteParams(remoteUrl: remoteUrl, token: event.token),
    );
    result.fold(
      (failure) => emit(SetupError(failure.message)),
      (config) => emit(SetupDone(config)),
    );
  }

  Future<void> _onLocalOnlyRequested(
    SetupLocalOnlyRequested event,
    Emitter<SetupState> emit,
  ) async {
    emit(const SetupValidating());
    final result = await _configureLocalOnly(const NoParams());
    result.fold(
      (failure) => emit(SetupError(failure.message)),
      (config) => emit(SetupDone(config)),
    );
  }
}
