import 'dart:ffi' show Abi;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
// Cross-feature imports — documented exception: the models screen of the
// onboarding/settings unifies the two on-device downloads the app needs,
// which live in the capture (STT) and assistant (LLM) features.
import '../../../assistant/domain/entities/ai_model_option.dart';
import '../../../assistant/domain/repositories/assistant_repository.dart';
import '../../../capture/domain/services/transcription_service.dart';
import '../../../capture/domain/usecases/ensure_stt_model.dart';

part 'models_install_state.dart';

/// Signature of the local-AI platform support check (see docs/DECISIONS.md:
/// flutter_gemma has no macOS Intel nor Windows arm64 build).
typedef AssistantSupportCheck = bool Function();

bool _abiSupportsLocalAi() {
  final abi = Abi.current();
  return abi != Abi.macosX64 && abi != Abi.windowsArm64;
}

/// Drives the models screen (onboarding final step and « Réglages →
/// Modèles ») : per-model install status and download progress for
/// - the voice models (sherpa-onnx dictation + transcription; one merged
///   progress because [EnsureSttModel] exposes a single global stream);
/// - the assistant LLM (Gemma/Qwen via [AssistantRepository]).
///
/// Registered as a lazy singleton so a download started during onboarding
/// keeps running after « Continuer en arrière-plan » navigates away — the
/// cubit outlives every page that displays it.
@lazySingleton
class ModelsInstallCubit extends Cubit<ModelsInstallState> {
  ModelsInstallCubit(
    this._transcription,
    this._ensureSttModel,
    this._assistantRepository, {
    @ignoreParam AssistantSupportCheck? isAssistantSupported,
  }) : _isAssistantSupported = isAssistantSupported ?? _abiSupportsLocalAi,
       super(const ModelsInstallState.initial());

  static const assistantUnsupportedMessage =
      'L’assistant local n’est pas pris en charge sur cet appareil '
      '(macOS Intel et Windows ARM). Vos notes restent entièrement '
      'utilisables.';

  static const downloadFailedMessage =
      'Le téléchargement a échoué. Vérifiez votre connexion puis réessayez.';

  final TranscriptionService _transcription;
  final EnsureSttModel _ensureSttModel;
  final AssistantRepository _assistantRepository;
  final AssistantSupportCheck _isAssistantSupported;

  /// Refreshes the installed/not-installed status of both models. Never
  /// clobbers a download already in progress (the screen can remount while
  /// a background download runs).
  Future<void> init() async {
    await Future.wait([_checkVoice(), _checkAssistant()]);
  }

  Future<void> _checkVoice() async {
    if (state.voice.isDownloading) return;
    _emitVoice(const ModelInstallInfo.checking());
    var ready = false;
    try {
      ready = await _transcription.isReady();
    } on Exception {
      // A failed presence check simply means the download is (re)offered.
      ready = false;
    }
    if (isClosed) return;
    _emitVoice(
      ready
          ? const ModelInstallInfo.ready()
          : const ModelInstallInfo.notInstalled(),
    );
  }

  Future<void> _checkAssistant() async {
    if (!_isAssistantSupported()) {
      _emitAssistant(
        const ModelInstallInfo.unsupported(assistantUnsupportedMessage),
      );
      return;
    }
    if (state.assistant.isDownloading) return;
    _emitAssistant(const ModelInstallInfo.checking());
    final result = await _assistantRepository.isReady();
    if (isClosed) return;
    result.fold(
      (failure) => _emitAssistant(ModelInstallInfo.failed(failure.message)),
      (ready) => _emitAssistant(
        ready
            ? const ModelInstallInfo.ready()
            : const ModelInstallInfo.notInstalled(),
      ),
    );
  }

  /// Downloads the voice (STT) models, reporting merged progress 0 → 1.
  Future<void> downloadVoice() async {
    if (state.voice.isDownloading ||
        state.voice.phase == ModelInstallPhase.ready) {
      return;
    }
    _emitVoice(const ModelInstallInfo.downloading(0));
    try {
      await for (final step in _ensureSttModel(const NoParams())) {
        if (isClosed) return;
        final hadFailure = step.fold(
          (failure) {
            _emitVoice(ModelInstallInfo.failed(failure.message));
            return true;
          },
          (progress) {
            _emitVoice(ModelInstallInfo.downloading(progress));
            return false;
          },
        );
        if (hadFailure) return;
      }
    } on Exception {
      if (!isClosed) {
        _emitVoice(const ModelInstallInfo.failed(downloadFailedMessage));
      }
      return;
    }
    if (isClosed) return;
    _emitVoice(const ModelInstallInfo.ready());
  }

  /// Downloads the assistant LLM, reporting progress 0 → 1.
  Future<void> downloadAssistant() async {
    if (state.assistant.isDownloading ||
        state.assistant.phase == ModelInstallPhase.ready ||
        state.assistant.phase == ModelInstallPhase.unsupported) {
      return;
    }
    _emitAssistant(const ModelInstallInfo.downloading(0));
    try {
      await for (final step in _assistantRepository.installModel()) {
        if (isClosed) return;
        final hadFailure = step.fold(
          (failure) {
            _emitAssistant(ModelInstallInfo.failed(failure.message));
            return true;
          },
          (progress) {
            _emitAssistant(ModelInstallInfo.downloading(progress));
            return false;
          },
        );
        if (hadFailure) return;
      }
    } on Exception {
      if (!isClosed) {
        _emitAssistant(const ModelInstallInfo.failed(downloadFailedMessage));
      }
      return;
    }
    if (isClosed) return;
    _emitAssistant(const ModelInstallInfo.ready());
  }

  /// The assistant model currently selected, or `null` before any choice
  /// (falls back to Qwen3 when actually installing — see
  /// `GemmaModelCatalog.defaultModelId`).
  Future<AiModelId?> currentAssistantSelection() async {
    final result = await _assistantRepository.getSelectedModel();
    return result.fold((_) => null, (id) => id);
  }

  /// Persists [modelId] as the assistant's chosen model, then (re)downloads
  /// it — including when a different model was already installed: resets
  /// the phase first so [downloadAssistant]'s "already ready" guard does
  /// not block the switch.
  Future<void> selectAssistantModel(AiModelId modelId) async {
    // Guards against a double-tap on two choice tiles racing each other
    // into two concurrent downloads.
    if (state.assistant.isDownloading) return;
    final result = await _assistantRepository.selectModel(modelId);
    final failure = result.fold((failure) => failure, (_) => null);
    if (failure != null) {
      if (!isClosed) _emitAssistant(ModelInstallInfo.failed(failure.message));
      return;
    }
    if (isClosed) return;
    _emitAssistant(const ModelInstallInfo.notInstalled());
    await downloadAssistant();
  }

  void _emitVoice(ModelInstallInfo info) =>
      emit(state.copyWith(voice: info));

  void _emitAssistant(ModelInstallInfo info) =>
      emit(state.copyWith(assistant: info));

  /// get_it dispose hook. Must never await an external stream future (see
  /// the BDD harness notes); closing the cubit only closes its own state
  /// controller.
  @disposeMethod
  Future<void> dispose() => close();
}
