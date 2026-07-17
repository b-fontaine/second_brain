import 'package:equatable/equatable.dart';

/// State of the « Semer cette synthèse » action of the chat.
sealed class SowSynthesisState extends Equatable {
  const SowSynthesisState();

  @override
  List<Object?> get props => const [];
}

/// No seeding in progress.
final class SowSynthesisIdle extends SowSynthesisState {
  const SowSynthesisIdle();
}

/// The synthesis is being analyzed and written to the nursery inbox.
final class SowSynthesisSowing extends SowSynthesisState {
  const SowSynthesisSowing();
}

/// The synthesis landed in the Pépinière (transient: consumed by the
/// SnackBar listener, which resets to idle).
final class SowSynthesisSown extends SowSynthesisState {
  const SowSynthesisSown();
}

/// The seeding failed (transient: consumed by the SnackBar listener).
final class SowSynthesisFailure extends SowSynthesisState {
  const SowSynthesisFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
