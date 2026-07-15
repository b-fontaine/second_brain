// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/i_see_the_empty_zettelkasten_home_screen.dart';
import './step/i_see_text.dart';
import './step/a_zettel_titled_exists.dart';
import './step/the_zettel_links_to.dart';
import './step/the_graph_contains_nodes.dart';
import './step/the_graph_contains_edge.dart';
import './step/i_select_the_graph_node.dart';
import './step/the_node_is_highlighted.dart';
import './step/the_sheet_peek_shows_the_selected_note.dart';
import './step/i_search_for_in_the_note_list.dart';
import './step/the_search_results_show.dart';
import './step/the_constellation_lights_node.dart';
import './step/i_raise_the_explorer_sheet.dart';
import './step/the_note_list_shows_a_tile_titled.dart';
import './step/i_zoom_into_the_graph.dart';
import './step/the_graph_viewport_scale_increases.dart';

void main() {
  group('''Constellation de l'Explorer (La Serre)''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
    }

    testWidgets('''Jardin vide — une pousse invite à semer la première idée''',
        (tester) async {
      await bddSetUp(tester);
      await iSeeTheEmptyZettelkastenHomeScreen(tester);
      await iSeeText(
          tester, 'Semez votre première idée avec le bouton « Semer ».');
    });
    testWidgets(
        '''La constellation montre un nœud par note et un lien par wikilink''',
        (tester) async {
      await bddSetUp(tester);
      await aZettelTitledExists(tester, 'Concept A');
      await aZettelTitledExists(tester, 'Concept B');
      await theZettelLinksTo(tester, 'Concept A', 'Concept B');
      await theGraphContainsNodes(tester, 2);
      await theGraphContainsEdge(tester, 1);
    });
    testWidgets('''Sélectionner un nœud remonte l'aperçu de la note''',
        (tester) async {
      await bddSetUp(tester);
      await aZettelTitledExists(tester, 'Concept A');
      await aZettelTitledExists(tester, 'Concept B');
      await theZettelLinksTo(tester, 'Concept A', 'Concept B');
      await iSelectTheGraphNode(tester, 'Concept A');
      await theNodeIsHighlighted(tester, 'Concept A');
      await theSheetPeekShowsTheSelectedNote(tester, 'Concept A');
    });
    testWidgets('''La recherche allume les notes correspondantes''',
        (tester) async {
      await bddSetUp(tester);
      await aZettelTitledExists(tester, 'Photosynthèse');
      await aZettelTitledExists(tester, 'Mitochondrie');
      await iSearchForInTheNoteList(tester, 'Photosynthèse');
      await theSearchResultsShow(tester, 'Photosynthèse');
      await theConstellationLightsNode(tester, 1);
    });
    testWidgets('''Le tiroir remonté liste les notes du jardin''',
        (tester) async {
      await bddSetUp(tester);
      await aZettelTitledExists(tester, 'Concept A');
      await aZettelTitledExists(tester, 'Concept B');
      await iRaiseTheExplorerSheet(tester);
      await theNoteListShowsATileTitled(tester, 'Concept A');
      await theNoteListShowsATileTitled(tester, 'Concept B');
    });
    testWidgets('''La constellation se zoome à la molette''', (tester) async {
      await bddSetUp(tester);
      await aZettelTitledExists(tester, 'Concept A');
      await aZettelTitledExists(tester, 'Concept B');
      await theZettelLinksTo(tester, 'Concept A', 'Concept B');
      await iZoomIntoTheGraph(tester);
      await theGraphViewportScaleIncreases(tester);
    });
  });
}
