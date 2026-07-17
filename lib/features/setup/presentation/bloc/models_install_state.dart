part of 'models_install_cubit.dart';

/// Lifecycle phase of one on-device model bundle.
enum ModelInstallPhase {
  /// Presence check in progress (static label, no spinner).
  checking,

  /// Not on disk yet: the download button is offered.
  notInstalled,

  /// Download in progress (determinate [ModelInstallInfo.progress]).
  downloading,

  /// Installed and usable.
  ready,

  /// Download or check failed; retry offered with [ModelInstallInfo.message].
  failed,

  /// Platform without a runtime for this model (assistant only).
  unsupported,
}

/// Status + progress of one model bundle of the models screen.
class ModelInstallInfo extends Equatable {
  const ModelInstallInfo._(this.phase, this.progress, this.message);

  const ModelInstallInfo.checking() : this._(ModelInstallPhase.checking, 0, null);

  const ModelInstallInfo.notInstalled()
    : this._(ModelInstallPhase.notInstalled, 0, null);

  const ModelInstallInfo.downloading(double progress)
    : this._(ModelInstallPhase.downloading, progress, null);

  const ModelInstallInfo.ready() : this._(ModelInstallPhase.ready, 1, null);

  const ModelInstallInfo.failed(String message)
    : this._(ModelInstallPhase.failed, 0, message);

  const ModelInstallInfo.unsupported(String message)
    : this._(ModelInstallPhase.unsupported, 0, message);

  final ModelInstallPhase phase;

  /// 0.0 → 1.0, meaningful while [phase] is [ModelInstallPhase.downloading].
  final double progress;

  /// Failure or unsupported-platform detail, displayed as-is.
  final String? message;

  bool get isDownloading => phase == ModelInstallPhase.downloading;

  @override
  List<Object?> get props => [phase, progress, message];
}

/// Combined state of the two model bundles (voice STT + assistant LLM).
class ModelsInstallState extends Equatable {
  const ModelsInstallState({required this.voice, required this.assistant});

  const ModelsInstallState.initial()
    : this(
        voice: const ModelInstallInfo.checking(),
        assistant: const ModelInstallInfo.checking(),
      );

  /// Sherpa-onnx dictation + transcription models. ONE merged progress:
  /// `SttModelStore.install()` exposes a single global stream over its two
  /// model bundles, so they cannot be split further per model.
  final ModelInstallInfo voice;

  /// On-device LLM (Gemma/Qwen) of the assistant.
  final ModelInstallInfo assistant;

  bool get anyDownloading => voice.isDownloading || assistant.isDownloading;

  /// Every model settled (ready, failed or unsupported — nothing pending).
  bool get allSettled =>
      _settled(voice.phase) && _settled(assistant.phase);

  static bool _settled(ModelInstallPhase phase) =>
      phase == ModelInstallPhase.ready ||
      phase == ModelInstallPhase.unsupported;

  ModelsInstallState copyWith({
    ModelInstallInfo? voice,
    ModelInstallInfo? assistant,
  }) {
    return ModelsInstallState(
      voice: voice ?? this.voice,
      assistant: assistant ?? this.assistant,
    );
  }

  @override
  List<Object?> get props => [voice, assistant];
}
