import 'package:equatable/equatable.dart';

/// Events of the RAG chat.
sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => const [];
}

/// The user submitted a question (typed, dictated or from a suggestion).
final class ChatQuestionSubmitted extends ChatEvent {
  const ChatQuestionSubmitted(this.question);

  final String question;

  @override
  List<Object?> get props => [question];
}
