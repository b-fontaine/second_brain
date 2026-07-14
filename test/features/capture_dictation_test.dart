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
import './step/i_stop_dictating.dart';
import './step/the_transcript_contains.dart';
import './step/a_dictated_transcript_about.dart';
import './step/i_run_the_capture_assistant_on_the_transcript.dart';
import './step/the_assistant_proposes_at_least_zettel_draft.dart';

void main() {
  group('''Dictation capture with live transcription''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await theLocalAiModelIsAvailable(tester);
      await theLocalTranscriptionEngineIsAvailable(tester);
    }

    testWidgets('''Dictating produces a live transcript''', (tester) async {
      await bddSetUp(tester);
      await iTapTheSeedButton(tester);
      await iChooseToDictate(tester);
      await iSpeak(tester, 'ceci est une note dictée');
      await iStopDictating(tester);
      await theTranscriptContains(tester, 'ceci est une note dictée');
    });
    testWidgets('''The assistant files the dictated transcript''',
        (tester) async {
      await bddSetUp(tester);
      await aDictatedTranscriptAbout(tester, 'la revue de code');
      await iRunTheCaptureAssistantOnTheTranscript(tester);
      await theAssistantProposesAtLeastZettelDraft(tester, 1);
    });
  });
}
