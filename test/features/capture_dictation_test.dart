// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/the_local_ai_model_is_available.dart';
import './step/the_local_transcription_engine_is_available.dart';
import './step/i_tap_the_seed_button.dart';
import './step/i_choose_to_dictate.dart';
import './step/i_speak.dart';
import './step/the_transcript_contains.dart';
import './step/i_stop_dictating.dart';
import './step/the_explorer_confirms_the_seeding.dart';
import './step/the_inbox_contains_pending_item.dart';
import './step/i_open_the_nursery_from_the_explorer_pill.dart';
import './step/the_nursery_shows_the_seedling_titled.dart';

void main() {
  group('''Dictation seeding straight to the nursery''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await theLocalAiModelIsAvailable(tester);
      await theLocalTranscriptionEngineIsAvailable(tester);
    }

    testWidgets('''Dicter affiche la transcription en direct''',
        (tester) async {
      await bddSetUp(tester);
      await iTapTheSeedButton(tester);
      await iChooseToDictate(tester);
      await iSpeak(tester, 'ceci est une note dictée');
      await theTranscriptContains(tester, 'ceci est une note dictée');
    });
    testWidgets('''Arrêter la dictée sème le brouillon en pépinière''',
        (tester) async {
      await bddSetUp(tester);
      await iTapTheSeedButton(tester);
      await iChooseToDictate(tester);
      await iSpeak(tester, 'penser à pailler les fraisiers avant les gelées');
      await iStopDictating(tester);
      await theExplorerConfirmsTheSeeding(tester);
      await theInboxContainsPendingItem(tester, 1);
      await iOpenTheNurseryFromTheExplorerPill(tester);
      await theNurseryShowsTheSeedlingTitled(
          tester, 'penser à pailler les fraisiers avant les gelées');
    });
  });
}
