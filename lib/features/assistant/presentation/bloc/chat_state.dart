import 'package:equatable/equatable.dart';

import '../../domain/entities/assistant_answer.dart';

/// Author of a [ChatMessage].
enum ChatMessageRole { user, assistant }

/// A single message of the in-session chat history.
class ChatMessage extends Equatable {
  const ChatMessage._({
    required this.role,
    required this.text,
    this.sources = const [],
    this.related = const [],
    this.isError = false,
  });

  /// Message typed (or dictated) by the user.
  factory ChatMessage.user(String text) =>
      ChatMessage._(role: ChatMessageRole.user, text: text);

  /// Answer produced by the assistant (markdown, may contain `[[id]]`).
  factory ChatMessage.assistant({
    required String text,
    List<AssistantSource> sources = const [],
    List<AssistantSource> related = const [],
  }) => ChatMessage._(
    role: ChatMessageRole.assistant,
    text: text,
    sources: sources,
    related: related,
  );

  /// Inline error bubble shown in place of an assistant answer.
  factory ChatMessage.error(String message) => ChatMessage._(
    role: ChatMessageRole.assistant,
    text: message,
    isError: true,
  );

  final ChatMessageRole role;

  /// Plain text (user) or markdown (assistant).
  final String text;

  /// Notes cited as sources by the assistant, most relevant first
  /// (« Sources » chips under the bubble).
  final List<AssistantSource> sources;

  /// Notes retrieved as context but not cited (« Et peut-être »).
  final List<AssistantSource> related;

  /// True when this bubble reports a failure instead of an answer.
  final bool isError;

  @override
  List<Object?> get props => [role, text, sources, related, isError];
}

/// State of the RAG chat screen.
sealed class ChatState extends Equatable {
  const ChatState(this.messages);

  /// In-memory session history, oldest first.
  final List<ChatMessage> messages;

  @override
  List<Object?> get props => [messages];
}

/// No generation in progress.
final class ChatIdle extends ChatState {
  const ChatIdle([super.messages = const []]);
}

/// The assistant is generating an answer to the last user question.
final class ChatGenerating extends ChatState {
  const ChatGenerating(super.messages);
}
