import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/assistant/domain/entities/assistant_answer.dart';
import 'package:second_brain/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:second_brain/features/assistant/presentation/bloc/chat_bloc.dart';
import 'package:second_brain/features/assistant/presentation/bloc/chat_event.dart';
import 'package:second_brain/features/assistant/presentation/bloc/chat_state.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';

class MockAssistantRepository extends Mock implements AssistantRepository {}

void main() {
  late MockAssistantRepository repository;

  setUp(() {
    repository = MockAssistantRepository();
  });

  group('ChatBloc', () {
    const question = 'Que sais-je sur la mémoire de travail ?';
    final citedId = ZettelId.fromString('20260101120000');
    final answer = AssistantAnswer(
      text: 'La mémoire de travail est limitée [[20260101120000]].',
      citedZettels: [citedId],
    );

    test('initial state is an empty idle conversation', () {
      expect(ChatBloc(repository).state, const ChatIdle());
    });

    blocTest<ChatBloc, ChatState>(
      'emits generating then idle with the assistant answer on success',
      setUp: () {
        when(
          () => repository.answerQuestion(question),
        ).thenAnswer((_) async => Right(answer));
      },
      build: () => ChatBloc(repository),
      act: (bloc) => bloc.add(const ChatQuestionSubmitted(question)),
      expect: () => [
        ChatGenerating([ChatMessage.user(question)]),
        ChatIdle([
          ChatMessage.user(question),
          ChatMessage.assistant(text: answer.text, citedZettels: [citedId]),
        ]),
      ],
      verify: (_) {
        verify(() => repository.answerQuestion(question)).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'emits an inline French error message when the repository fails',
      setUp: () {
        when(() => repository.answerQuestion(question)).thenAnswer(
          (_) async => const Left(AiFailure('Le modèle n’est pas prêt.')),
        );
      },
      build: () => ChatBloc(repository),
      act: (bloc) => bloc.add(const ChatQuestionSubmitted(question)),
      expect: () => [
        ChatGenerating([ChatMessage.user(question)]),
        ChatIdle([
          ChatMessage.user(question),
          ChatMessage.error('Le modèle n’est pas prêt.'),
        ]),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'keeps the previous exchanges in the session history',
      setUp: () {
        when(
          () => repository.answerQuestion(question),
        ).thenAnswer((_) async => Right(answer));
      },
      build: () => ChatBloc(repository),
      seed: () => ChatIdle([
        ChatMessage.user('Bonjour'),
        ChatMessage.assistant(text: 'Bonjour !'),
      ]),
      act: (bloc) => bloc.add(const ChatQuestionSubmitted(question)),
      expect: () => [
        ChatGenerating([
          ChatMessage.user('Bonjour'),
          ChatMessage.assistant(text: 'Bonjour !'),
          ChatMessage.user(question),
        ]),
        ChatIdle([
          ChatMessage.user('Bonjour'),
          ChatMessage.assistant(text: 'Bonjour !'),
          ChatMessage.user(question),
          ChatMessage.assistant(text: answer.text, citedZettels: [citedId]),
        ]),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'ignores blank questions',
      build: () => ChatBloc(repository),
      act: (bloc) => bloc.add(const ChatQuestionSubmitted('   ')),
      expect: () => const <ChatState>[],
      verify: (_) {
        verifyNever(() => repository.answerQuestion(any()));
      },
    );
  });
}
