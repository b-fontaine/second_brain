import 'dart:ffi' show Abi;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/ai_model_option.dart';
import '../../domain/repositories/assistant_repository.dart';
import 'model_status_state.dart';

/// Signature of the local-AI platform support check.
typedef LocalAiSupportCheck = bool Function();

/// Architectures without a local AI runtime (see docs/DECISIONS.md:
/// flutter_gemma has no macOS Intel nor Windows arm64 build).
bool _abiSupportsLocalAi() {
  final abi = Abi.current();
  return abi != Abi.macosX64 && abi != Abi.windowsArm64;
}

/// Tracks the lifecycle of the on-device model: installed, downloading
/// with progress, unsupported platform (degraded mode) or error.
@injectable
class ModelStatusCubit extends Cubit<ModelStatusState> {
  ModelStatusCubit(
    this._repository, {
    @ignoreParam LocalAiSupportCheck? isLocalAiSupported,
  }) : _isLocalAiSupported = isLocalAiSupported ?? _abiSupportsLocalAi,
       super(const ModelStatusChecking());

  static const unsupportedMessage =
      'L’IA locale n’est pas prise en charge sur cet appareil '
      '(macOS Intel et Windows ARM). L’assistant est désactivé, '
      'mais vos notes restent entièrement utilisables.';

  static const modelMissingAfterInstallMessage =
      'Le modèle est introuvable après le téléchargement. Veuillez réessayer.';

  static const downloadFailedMessage =
      'Le téléchargement du modèle a échoué. '
      'Vérifiez votre connexion puis réessayez.';

  final AssistantRepository _repository;
  final LocalAiSupportCheck _isLocalAiSupported;

  /// Checks platform support, then whether the model is installed.
  Future<void> check() async {
    if (!_isLocalAiSupported()) {
      emit(const ModelStatusUnsupported(unsupportedMessage));
      return;
    }
    emit(const ModelStatusChecking());
    final result = await _repository.isReady();
    if (isClosed) return;
    result.fold(
      (failure) => emit(ModelStatusError(failure.message)),
      (ready) => emit(
        ready ? const ModelStatusReady() : const ModelStatusNotInstalled(),
      ),
    );
  }

  /// The model currently selected, or `null` before any explicit choice.
  Future<AiModelId?> currentSelection() async {
    final result = await _repository.getSelectedModel();
    return result.fold((_) => null, (id) => id);
  }

  /// Persists [modelId] as the user's choice, then downloads it.
  ///
  /// Used by the onboarding model-choice screen and the settings screen;
  /// a selection failure (disk error) surfaces as [ModelStatusError]
  /// without attempting the download.
  Future<void> selectAndDownload(AiModelId modelId) async {
    final result = await _repository.selectModel(modelId);
    final failure = result.fold((failure) => failure, (_) => null);
    if (failure != null) {
      if (!isClosed) emit(ModelStatusError(failure.message));
      return;
    }
    await download();
  }

  /// Downloads and installs the on-device model, reporting progress,
  /// then re-verifies the installation.
  Future<void> download() async {
    if (state is ModelStatusDownloading) return;
    if (!_isLocalAiSupported()) {
      emit(const ModelStatusUnsupported(unsupportedMessage));
      return;
    }
    emit(const ModelStatusDownloading(0));
    try {
      await for (final step in _repository.installModel()) {
        if (isClosed) return;
        final failed = step.fold(
          (failure) {
            emit(ModelStatusError(failure.message));
            return true;
          },
          (progress) {
            emit(ModelStatusDownloading(progress));
            return false;
          },
        );
        if (failed) return;
      }
    } on Exception {
      if (!isClosed) emit(const ModelStatusError(downloadFailedMessage));
      return;
    }
    if (isClosed) return;
    final result = await _repository.isReady();
    if (isClosed) return;
    result.fold(
      (failure) => emit(ModelStatusError(failure.message)),
      (ready) => emit(
        ready
            ? const ModelStatusReady()
            : const ModelStatusError(modelMissingAfterInstallMessage),
      ),
    );
  }
}
