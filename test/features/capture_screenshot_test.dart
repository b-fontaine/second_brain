// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/the_local_ai_model_is_available.dart';
import './step/the_local_ocr_engine_is_available.dart';
import './step/i_tap_the_seed_button.dart';
import './step/i_choose_to_add_a_file.dart';
import './step/i_import_the_image_file.dart';
import './step/the_seed_preview_shows_the_detected_type.dart';
import './step/the_seed_preview_text_contains.dart';
import './step/the_ocr_engine_reads.dart';
import './step/i_sow_the_seed_preview.dart';
import './step/the_explorer_confirms_the_seeding.dart';
import './step/the_inbox_contains_pending_item.dart';
import './step/i_open_the_nursery_from_the_explorer_pill.dart';
import './step/the_nursery_shows_the_seedling_titled.dart';

void main() {
  group('''Image seeding with OCR through the sowing preview''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await theLocalAiModelIsAvailable(tester);
      await theLocalOcrEngineIsAvailable(tester);
    }

    testWidgets(
        '''Importer une image reconnaît son texte vers l'aperçu avant semis''',
        (tester) async {
      await bddSetUp(tester);
      await iTapTheSeedButton(tester);
      await iChooseToAddAFile(tester);
      await iImportTheImageFile(tester, 'diapositive_conference.png');
      await theSeedPreviewShowsTheDetectedType(tester, 'Image');
      await theSeedPreviewTextContains(
          tester, 'Texte reconnu sur la diapositive');
    });
    testWidgets('''Semer une image océrisée dépose un brouillon en pépinière''',
        (tester) async {
      await bddSetUp(tester);
      await theOcrEngineReads(
          tester, 'Croquis du plan de rotation des cultures');
      await iTapTheSeedButton(tester);
      await iChooseToAddAFile(tester);
      await iImportTheImageFile(tester, 'plan_rotation.png');
      await iSowTheSeedPreview(tester);
      await theExplorerConfirmsTheSeeding(tester);
      await theInboxContainsPendingItem(tester, 1);
      await iOpenTheNurseryFromTheExplorerPill(tester);
      await theNurseryShowsTheSeedlingTitled(
          tester, 'Croquis du plan de rotation des cultures');
    });
  });
}
