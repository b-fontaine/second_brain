// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/the_local_ai_model_is_available.dart';
import './step/a_zettel_titled_exists_with_content_about_capacity_limits.dart';
import './step/i_open_the_assistant_chat.dart';
import './step/i_ask.dart';
import './step/the_assistant_answers_using_the_zettelkasten_content.dart';
import './step/the_answer_cites_the_zettel_as_source.dart';
import './step/the_assistant_answered_citing.dart';
import './step/i_tap_the_cited_source.dart';
import './step/i_see_the_note_reading_panel_with_title.dart';
import './step/the_local_transcription_engine_is_available.dart';
import './step/i_ask_by_voice.dart';
import './step/i_tap_button.dart';
import './step/i_see_text.dart';
import './step/the_inbox_contains_pending_item.dart';

void main() {
  group('''Querying the knowledge base by prompt''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await theLocalAiModelIsAvailable(tester);
      await aZettelTitledExistsWithContentAboutCapacityLimits(
          tester, 'Mémoire de travail');
    }

    testWidgets('''Asking a written question returns an answer with sources''',
        (tester) async {
      await bddSetUp(tester);
      await iOpenTheAssistantChat(tester);
      await iAsk(tester, 'Que sais-je sur la mémoire de travail ?');
      await theAssistantAnswersUsingTheZettelkastenContent(tester);
      await theAnswerCitesTheZettelAsSource(tester, 'Mémoire de travail');
    });
    testWidgets('''Tapping a cited source opens the zettel''', (tester) async {
      await bddSetUp(tester);
      await theAssistantAnsweredCiting(tester, 'Mémoire de travail');
      await iTapTheCitedSource(tester, 'Mémoire de travail');
      await iSeeTheNoteReadingPanelWithTitle(tester, 'Mémoire de travail');
    });
    testWidgets('''Asking a question by voice''', (tester) async {
      await bddSetUp(tester);
      await theLocalTranscriptionEngineIsAvailable(tester);
      await iOpenTheAssistantChat(tester);
      await iAskByVoice(tester, 'Que sais-je sur la mémoire de travail ?');
      await theAssistantAnswersUsingTheZettelkastenContent(tester);
    });
    testWidgets('''Semer la synthèse envoie la réponse en pépinière''',
        (tester) async {
      await bddSetUp(tester);
      await theAssistantAnsweredCiting(tester, 'Mémoire de travail');
      await iTapButton(tester, 'Semer cette synthèse');
      await iSeeText(tester, 'Semé en pépinière — brouillon à valider.');
      await theInboxContainsPendingItem(tester, 1);
    });
  });
}
