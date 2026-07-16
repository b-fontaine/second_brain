// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/a_sown_seedling_titled_with_the_parcelle.dart';
import './step/i_open_the_nursery_from_the_explorer_pill.dart';
import './step/i_see_text.dart';
import './step/the_nursery_shows_the_seedling_titled.dart';
import './step/i_transplant_the_seedling_titled.dart';
import './step/a_zettel_exists_with_title.dart';
import './step/the_draft_references_the_original_capture_as_source.dart';
import './step/the_inbox_contains_pending_item.dart';
import './step/i_compost_the_seedling_titled.dart';
import './step/no_zettel_exists_with_title.dart';
import './step/the_explorer_seedling_pill_shows.dart';
import './step/i_return_to_the_explorer.dart';
import './step/the_explorer_seedling_pill_is_hidden.dart';
import './step/i_open_the_empty_nursery.dart';
import './step/i_tap_button.dart';

void main() {
  group('''Nursery review of the sown drafts''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
    }

    testWidgets('''La pépinière liste les semis en attente de validation''',
        (tester) async {
      await bddSetUp(tester);
      await aSownSeedlingTitledWithTheParcelle(
          tester, 'Arrosage des cultures hydroponiques', 'hydroponie');
      await aSownSeedlingTitledWithTheParcelle(
          tester, 'Greffe des agrumes en hiver', 'verger');
      await iOpenTheNurseryFromTheExplorerPill(tester);
      await iSeeText(tester,
          '2 brouillons à valider — repiquez-les en notes ou compostez-les.');
      await theNurseryShowsTheSeedlingTitled(
          tester, 'Arrosage des cultures hydroponiques');
      await theNurseryShowsTheSeedlingTitled(
          tester, 'Greffe des agrumes en hiver');
      await iSeeText(tester, 'hydroponie');
    });
    testWidgets('''Repiquer un semis crée la note au jardin''', (tester) async {
      await bddSetUp(tester);
      await aSownSeedlingTitledWithTheParcelle(
          tester, 'Paillage du potager en été', 'potager');
      await iOpenTheNurseryFromTheExplorerPill(tester);
      await iTransplantTheSeedlingTitled(tester, 'Paillage du potager en été');
      await iSeeText(tester,
          'Repiqué au jardin — note « Paillage du potager en été » créée.');
      await aZettelExistsWithTitle(tester, 'Paillage du potager en été');
      await theDraftReferencesTheOriginalCaptureAsSource(tester);
      await theInboxContainsPendingItem(tester, 0);
    });
    testWidgets('''Composter un semis supprime le brouillon''', (tester) async {
      await bddSetUp(tester);
      await aSownSeedlingTitledWithTheParcelle(
          tester, 'Taille des rosiers anciens', 'roseraie');
      await iOpenTheNurseryFromTheExplorerPill(tester);
      await iCompostTheSeedlingTitled(tester, 'Taille des rosiers anciens');
      await iSeeText(tester, 'Semis composté — brouillon supprimé.');
      await theInboxContainsPendingItem(tester, 0);
      await noZettelExistsWithTitle(tester, 'Taille des rosiers anciens');
    });
    testWidgets('''La pastille semis de l'explorateur suit le compte''',
        (tester) async {
      await bddSetUp(tester);
      await aSownSeedlingTitledWithTheParcelle(
          tester, 'Semis de tomates cerises', 'potager');
      await theExplorerSeedlingPillShows(tester, '1 semis');
      await iOpenTheNurseryFromTheExplorerPill(tester);
      await iTransplantTheSeedlingTitled(tester, 'Semis de tomates cerises');
      await iReturnToTheExplorer(tester);
      await theExplorerSeedlingPillIsHidden(tester);
    });
    testWidgets('''La pépinière vide invite à semer''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheEmptyNursery(tester);
      await iSeeText(tester, 'La pépinière est vide');
      await iTapButton(tester, 'Semer');
      await iSeeText(tester, 'Dicter');
      await iSeeText(tester, 'Coller');
    });
  });
}
