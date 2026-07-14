// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/the_local_ai_model_is_available.dart';
import './step/the_local_transcription_engine_is_available.dart';
import './step/i_tap_the_capture_button.dart';
import './step/i_choose_the_audio_capture_mode.dart';
import './step/i_import_the_audio_file.dart';
import './step/a_transcript_is_produced.dart';
import './step/the_transcript_is_shown_for_review.dart';
import './step/a_transcript_of_an_audio_note_about.dart';
import './step/i_run_the_capture_assistant_on_the_transcript.dart';
import './step/the_assistant_proposes_at_least_zettel_draft.dart';
import './step/each_draft_has_a_title_a_body_and_suggested_tags.dart';

void main() {
  group('''Audio capture with transcription assistant''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await theLocalAiModelIsAvailable(tester);
      await theLocalTranscriptionEngineIsAvailable(tester);
    }

    testWidgets('''Importing an audio file produces a transcript''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iTapTheCaptureButton(tester);
      await iChooseTheAudioCaptureMode(tester);
      await iImportTheAudioFile(tester, 'meeting.m4a');
      await aTranscriptIsProduced(tester);
      await theTranscriptIsShownForReview(tester);
    });
    testWidgets('''The assistant turns a transcript into zettel drafts''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await aTranscriptOfAnAudioNoteAbout(tester, 'les boucles de rétroaction');
      await iRunTheCaptureAssistantOnTheTranscript(tester);
      await theAssistantProposesAtLeastZettelDraft(tester, 1);
      await eachDraftHasATitleABodyAndSuggestedTags(tester);
    });
  });
}
