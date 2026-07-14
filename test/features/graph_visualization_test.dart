// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/a_zettel_titled_exists.dart';
import './step/the_zettel_links_to.dart';
import './step/i_open_the_graph_view.dart';
import './step/the_graph_contains_nodes.dart';
import './step/the_graph_contains_edge.dart';
import './step/i_select_the_graph_node.dart';
import './step/i_see_the_note_reading_panel_with_title.dart';
import './step/the_node_is_highlighted.dart';
import './step/i_zoom_into_the_graph.dart';
import './step/the_graph_viewport_scale_increases.dart';

void main() {
  group('''Molecular graph visualization of the zettelkasten''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await aZettelTitledExists(tester, 'Concept A');
      await aZettelTitledExists(tester, 'Concept B');
      await theZettelLinksTo(tester, 'Concept A', 'Concept B');
    }

    testWidgets('''The graph shows one node per zettel and edges for links''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iOpenTheGraphView(tester);
      await theGraphContainsNodes(tester, 2);
      await theGraphContainsEdge(tester, 1);
    });
    testWidgets('''Selecting a node opens the reading panel''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheGraphView(tester);
      await iSelectTheGraphNode(tester, 'Concept A');
      await iSeeTheNoteReadingPanelWithTitle(tester, 'Concept A');
      await theNodeIsHighlighted(tester, 'Concept A');
    });
    testWidgets('''The graph supports pan and zoom''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheGraphView(tester);
      await iZoomIntoTheGraph(tester);
      await theGraphViewportScaleIncreases(tester);
    });
  });
}
