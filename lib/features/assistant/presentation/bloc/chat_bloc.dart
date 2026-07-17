import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/assistant_repository.dart';
import 'chat_event.dart';
import 'chat_state.dart';

/// Drives the RAG chat: sends questions to the [AssistantRepository]
/// and keeps the conversation history in memory for the session.
///
/// Failures are surfaced as inline [ChatMessage.error] bubbles, never
/// as blocking dialogs.
@injectable
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(this._repository) : super(const ChatIdle()) {
    on<ChatQuestionSubmitted>(_onQuestionSubmitted);
  }

  final AssistantRepository _repository;

  Future<void> _onQuestionSubmitted(
    ChatQuestionSubmitted event,
    Emitter<ChatState> emit,
  ) async {
    final question = event.question.trim();
    if (question.isEmpty || state is ChatGenerating) return;

    final history = [...state.messages, ChatMessage.user(question)];
    emit(ChatGenerating(history));

    final result = await _repository.answerQuestion(question);
    result.fold(
      (failure) =>
          emit(ChatIdle([...history, ChatMessage.error(failure.message)])),
      (answer) => emit(
        ChatIdle([
          ...history,
          ChatMessage.assistant(
            text: answer.text,
            sources: answer.sources,
            related: answer.related,
          ),
        ]),
      ),
    );
  }
}
