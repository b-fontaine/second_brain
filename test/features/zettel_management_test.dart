// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/i_tap_the_new_note_button.dart';
import './step/i_enter_as_the_note_title.dart';
import './step/i_enter_as_the_note_body.dart';
import './step/i_save_the_note.dart';
import './step/a_zettel_exists_with_title.dart';
import './step/the_zettel_has_a_unique_timestamp_id.dart';
import './step/the_zettel_is_stored_as_a_markdown_file_with_frontmatter.dart';
import './step/a_zettel_titled_exists.dart';
import './step/i_open_the_zettel_titled.dart';
import './step/i_add_a_wikilink_to_in_the_body.dart';
import './step/the_zettel_links_to.dart';
import './step/the_zettel_shows_as_a_backlink.dart';
import './step/i_search_for_in_the_note_list.dart';
import './step/i_see_the_note_reading_panel_with_title.dart';
import './step/a_raw_capture_was_ingested.dart';
import './step/the_inbox_contains_pending_item.dart';
import './step/the_note_shows_its_mini_constellation.dart';
import './step/the_roots_section_lists_as_an_outgoing_link.dart';
import './step/the_roots_section_lists_as_an_incoming_link.dart';
import './step/a_zettel_titled_exists_with_content_about_capacity_limits.dart';
import './step/the_pollination_section_suggests.dart';
import './step/i_weave_the_pollination_suggestion.dart';
import './step/the_pollination_debounce_elapses.dart';
import './step/the_flower_banner_suggests_weaving.dart';

void main() {
  group('''Zettelkasten note management''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
    }

    testWidgets('''Creating a new zettel assigns a timestamp id''',
        (tester) async {
      await bddSetUp(tester);
      await iTapTheNewNoteButton(tester);
      await iEnterAsTheNoteTitle(tester, 'Ma première idée');
      await iEnterAsTheNoteBody(tester, 'Une idée atomique par note.');
      await iSaveTheNote(tester);
      await aZettelExistsWithTitle(tester, 'Ma première idée');
      await theZettelHasAUniqueTimestampId(tester);
      await theZettelIsStoredAsAMarkdownFileWithFrontmatter(tester);
    });
    testWidgets('''Linking two zettels with a wikilink''', (tester) async {
      await bddSetUp(tester);
      await aZettelTitledExists(tester, 'Concept A');
      await aZettelTitledExists(tester, 'Concept B');
      await iOpenTheZettelTitled(tester, 'Concept A');
      await iAddAWikilinkToInTheBody(tester, 'Concept B');
      await iSaveTheNote(tester);
      await theZettelLinksTo(tester, 'Concept A', 'Concept B');
      await theZettelShowsAsABacklink(tester, 'Concept B', 'Concept A');
    });
    testWidgets('''Browsing zettels from the home list''', (tester) async {
      await bddSetUp(tester);
      await aZettelTitledExists(tester, 'Concept A');
      await iSearchForInTheNoteList(tester, 'Concept A');
      await iOpenTheZettelTitled(tester, 'Concept A');
      await iSeeTheNoteReadingPanelWithTitle(tester, 'Concept A');
    });
    testWidgets('''Captured content lands in the inbox first''',
        (tester) async {
      await bddSetUp(tester);
      await aRawCaptureWasIngested(tester, 'Texte brut capturé');
      await theInboxContainsPendingItem(tester, 1);
    });
    testWidgets(
        '''Une note carrefour montre sa racine sortante et sa mini-constellation''',
        (tester) async {
      await bddSetUp(tester);
      await aZettelTitledExists(tester, 'Racine mère');
      await aZettelTitledExists(tester, 'Feuille fille');
      await theZettelLinksTo(tester, 'Racine mère', 'Feuille fille');
      await iOpenTheZettelTitled(tester, 'Racine mère');
      await theNoteShowsItsMiniConstellation(tester);
      await theRootsSectionListsAsAnOutgoingLink(tester, 'Feuille fille');
    });
    testWidgets('''Une note carrefour montre sa racine entrante''',
        (tester) async {
      await bddSetUp(tester);
      await aZettelTitledExists(tester, 'Racine mère');
      await aZettelTitledExists(tester, 'Feuille fille');
      await theZettelLinksTo(tester, 'Racine mère', 'Feuille fille');
      await iOpenTheZettelTitled(tester, 'Feuille fille');
      await theRootsSectionListsAsAnIncomingLink(tester, 'Racine mère');
    });
    testWidgets('''Tisser une pollinisation ajoute le wikilink à la note''',
        (tester) async {
      await bddSetUp(tester);
      await aZettelTitledExistsWithContentAboutCapacityLimits(
          tester, 'Mémoire de travail');
      await aZettelTitledExistsWithContentAboutCapacityLimits(
          tester, 'Attention sélective');
      await iOpenTheZettelTitled(tester, 'Mémoire de travail');
      await thePollinationSectionSuggests(tester, 'Attention sélective');
      await iWeaveThePollinationSuggestion(tester, 'Attention sélective');
      await theRootsSectionListsAsAnOutgoingLink(tester, 'Attention sélective');
      await theZettelLinksTo(
          tester, 'Mémoire de travail', 'Attention sélective');
    });
    testWidgets('''La fleur suggère de tisser pendant la frappe''',
        (tester) async {
      await bddSetUp(tester);
      await aZettelTitledExistsWithContentAboutCapacityLimits(
          tester, 'Mémoire de travail');
      await iTapTheNewNoteButton(tester);
      await iEnterAsTheNoteBody(
          tester, 'Les limites de capacité de la mémoire');
      await thePollinationDebounceElapses(tester);
      await theFlowerBannerSuggestsWeaving(tester, 'Mémoire de travail');
    });
  });
}
