import 'package:flutter_test/flutter_test.dart';

import 'i_ask.dart';
import 'i_open_the_assistant_chat.dart';
import 'the_answer_cites_the_zettel_as_source.dart';

/// Usage: the assistant answered citing {'Mémoire de travail'}
///
/// Given-style shortcut: opens the chat, asks a question about the note so
/// the keyword RAG index retrieves it, and checks the citation chip is
/// there — the exact state the following When steps build upon.
Future<void> theAssistantAnsweredCiting(
  WidgetTester tester,
  String param1,
) async {
  await iOpenTheAssistantChat(tester);
  await iAsk(tester, 'Que disent mes notes sur $param1 ?');
  await theAnswerCitesTheZettelAsSource(tester, param1);
}
