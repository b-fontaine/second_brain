import 'package:equatable/equatable.dart';

/// Lifecycle of the on-device LLM used by the assistant.
sealed class ModelStatusState extends Equatable {
  const ModelStatusState();

  @override
  List<Object?> get props => const [];
}

/// Checking whether the model is installed.
final class ModelStatusChecking extends ModelStatusState {
  const ModelStatusChecking();
}

/// The model must be downloaded before the assistant can answer.
final class ModelStatusNotInstalled extends ModelStatusState {
  const ModelStatusNotInstalled();
}

/// The model is being downloaded and installed.
final class ModelStatusDownloading extends ModelStatusState {
  const ModelStatusDownloading(this.progress);

  /// 0.0 → 1.0
  final double progress;

  @override
  List<Object?> get props => [progress];
}

/// The model is installed and ready for inference.
final class ModelStatusReady extends ModelStatusState {
  const ModelStatusReady();
}

/// Local AI is not available on this device: degraded, notes-only mode.
final class ModelStatusUnsupported extends ModelStatusState {
  const ModelStatusUnsupported(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Checking or installing the model failed.
final class ModelStatusError extends ModelStatusState {
  const ModelStatusError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
