import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/assistant/presentation/bloc/chat_bloc.dart';
import 'package:second_brain/features/assistant/presentation/bloc/chat_state.dart';
import 'package:second_brain/features/assistant/presentation/widgets/chat_input_bar.dart';
import 'package:second_brain/features/assistant/presentation/widgets/chat_message_bubble.dart';

import 'bdd_world.dart';

/// Usage: the assistant answers using the zettelkasten content
///
/// Verifies both sides of the RAG loop: the local model was prompted with
/// the vault notes as context (fake service call log), and the chat now
/// shows a successful assistant answer grounded in (citing) those notes.
Future<void> theAssistantAnswersUsingTheZettelkastenContent(
  WidgetTester tester,
) async {
  // The retrieval layer really fed vault content to the model.
  expect(
    fakeLocalAiService.generateCalls,
    isNotEmpty,
    reason: 'The assistant should have called the local model',
  );
  final call = fakeLocalAiService.generateCalls.last;
  expect(
    call.prompt,
    contains('Notes du Zettelkasten'),
    reason: 'The prompt should carry the retrieved zettelkasten context',
  );

  // The conversation ends with a successful, grounded assistant answer.
  final context = tester.element(find.byType(ChatInputBar));
  final messages = BlocProvider.of<ChatBloc>(context).state.messages;
  expect(
    messages,
    isNotEmpty,
    reason: 'The chat history should contain the exchange',
  );
  final answer = messages.last;
  expect(
    answer.role,
    ChatMessageRole.assistant,
    reason: 'The last message should be the assistant answer',
  );
  expect(
    answer.isError,
    isFalse,
    reason: 'The assistant should answer, not fail',
  );
  expect(answer.text, isNotEmpty);
  expect(
    answer.sources,
    isNotEmpty,
    reason: 'An answer built on the zettelkasten should cite zettels',
  );

  // And the answer is actually rendered as a chat bubble.
  expect(find.byType(ChatMessageBubble), findsWidgets);
}
