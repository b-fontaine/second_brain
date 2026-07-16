// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/the_local_ai_model_is_available.dart';
import './step/i_tap_the_seed_button.dart';
import './step/i_choose_to_paste.dart';
import './step/the_seed_preview_shows_the_detected_type.dart';
import './step/the_seed_preview_text_contains.dart';
import './step/the_clipboard_contains_a_note_about.dart';
import './step/the_seed_preview_proposes_the_title.dart';
import './step/i_sow_the_seed_preview.dart';
import './step/the_explorer_confirms_the_seeding.dart';
import './step/the_inbox_contains_pending_item.dart';
import './step/i_open_the_nursery_from_the_explorer_pill.dart';
import './step/the_nursery_shows_the_seedling_titled.dart';
import './step/the_local_ai_proposes_the_title_and_the_parcelle.dart';
import './step/i_see_text.dart';

void main() {
  group('''Clipboard seeding through the sowing preview''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await theLocalAiModelIsAvailable(tester);
    }

    testWidgets('''Coller ouvre l'aperçu avant semis avec le texte détecté''',
        (tester) async {
      await bddSetUp(tester);
      await iTapTheSeedButton(tester);
      await iChooseToPaste(tester);
      await theSeedPreviewShowsTheDetectedType(tester, 'Texte');
      await theSeedPreviewTextContains(tester, 'notes atomiques');
    });
    testWidgets('''Semer le texte collé dépose un brouillon en pépinière''',
        (tester) async {
      await bddSetUp(tester);
      await theClipboardContainsANoteAbout(tester, 'les jardins partagés');
      await iTapTheSeedButton(tester);
      await iChooseToPaste(tester);
      await theSeedPreviewProposesTheTitle(
          tester, 'Note copiée sur les jardins partagés');
      await iSowTheSeedPreview(tester);
      await theExplorerConfirmsTheSeeding(tester);
      await theInboxContainsPendingItem(tester, 1);
      await iOpenTheNurseryFromTheExplorerPill(tester);
      await theNurseryShowsTheSeedlingTitled(
          tester, 'Note copiée sur les jardins partagés');
    });
    testWidgets('''L'IA locale propose un titre et une parcelle sur l'aperçu''',
        (tester) async {
      await bddSetUp(tester);
      await theLocalAiProposesTheTitleAndTheParcelle(
          tester, 'Semis sous serre froide', 'serre');
      await iTapTheSeedButton(tester);
      await iChooseToPaste(tester);
      await theSeedPreviewProposesTheTitle(tester, 'Semis sous serre froide');
      await iSeeText(tester, 'serre');
      await iSowTheSeedPreview(tester);
      await iOpenTheNurseryFromTheExplorerPill(tester);
      await theNurseryShowsTheSeedlingTitled(tester, 'Semis sous serre froide');
      await iSeeText(tester, 'serre');
    });
  });
}
