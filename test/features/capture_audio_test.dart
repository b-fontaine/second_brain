// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/the_local_ai_model_is_available.dart';
import './step/the_local_transcription_engine_is_available.dart';
import './step/i_tap_the_seed_button.dart';
import './step/i_choose_to_add_a_file.dart';
import './step/i_import_the_audio_file.dart';
import './step/the_seed_preview_shows_the_detected_type.dart';
import './step/the_seed_preview_text_contains.dart';
import './step/the_transcription_engine_returns.dart';
import './step/i_sow_the_seed_preview.dart';
import './step/the_explorer_confirms_the_seeding.dart';
import './step/the_inbox_contains_pending_item.dart';
import './step/i_open_the_nursery_from_the_explorer_pill.dart';
import './step/the_nursery_shows_the_seedling_titled.dart';

void main() {
  group('''Audio file seeding through the sowing preview''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await theLocalAiModelIsAvailable(tester);
      await theLocalTranscriptionEngineIsAvailable(tester);
    }

    testWidgets(
        '''Importer un fichier audio transcrit vers l'aperçu avant semis''',
        (tester) async {
      await bddSetUp(tester);
      await iTapTheSeedButton(tester);
      await iChooseToAddAFile(tester);
      await iImportTheAudioFile(tester, 'reunion_hebdomadaire.m4a');
      await theSeedPreviewShowsTheDetectedType(tester, 'Audio');
      await theSeedPreviewTextContains(tester, 'Compte rendu de la réunion');
    });
    testWidgets(
        '''Semer une transcription audio dépose un brouillon en pépinière''',
        (tester) async {
      await bddSetUp(tester);
      await theTranscriptionEngineReturns(
          tester, 'Relevé vocal sur les ruches urbaines');
      await iTapTheSeedButton(tester);
      await iChooseToAddAFile(tester);
      await iImportTheAudioFile(tester, 'ruches_urbaines.m4a');
      await iSowTheSeedPreview(tester);
      await theExplorerConfirmsTheSeeding(tester);
      await theInboxContainsPendingItem(tester, 1);
      await iOpenTheNurseryFromTheExplorerPill(tester);
      await theNurseryShowsTheSeedlingTitled(
          tester, 'Relevé vocal sur les ruches urbaines');
    });
  });
}
