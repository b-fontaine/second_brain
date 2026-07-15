# Chantier 2 (plan Serre) : la constellation n'est plus une « vue graphe »
# séparée — elle EST la surface de l'Explorer (route `/`). Ancien fichier :
# graph_visualization.feature. Les assertions techniques (nœuds, arêtes,
# zoom, sélection) continuent de lire GraphCubit/GraphPainter à travers le
# CustomPaint de la constellation.
Feature: Constellation de l'Explorer (La Serre)
  En tant que jardinier de mes connaissances
  Je veux une surface unique mêlant constellation, recherche et liste
  Afin d'explorer mon jardin de notes visuellement

  Background:
    Given the app is running with a configured vault

  Scenario: Jardin vide — une pousse invite à semer la première idée
    Then I see the empty zettelkasten home screen
    And I see {'Semez votre première idée avec le bouton « Semer ».'} text

  Scenario: La constellation montre un nœud par note et un lien par wikilink
    Given a zettel titled {'Concept A'} exists
    And a zettel titled {'Concept B'} exists
    And the zettel {'Concept A'} links to {'Concept B'}
    Then the graph contains {2} nodes
    And the graph contains {1} edge

  Scenario: Sélectionner un nœud remonte l'aperçu de la note
    Given a zettel titled {'Concept A'} exists
    And a zettel titled {'Concept B'} exists
    And the zettel {'Concept A'} links to {'Concept B'}
    When I select the graph node {'Concept A'}
    Then the node {'Concept A'} is highlighted
    And the sheet peek shows the selected note {'Concept A'}

  # Titres sans lettres communes avec le corps généré par le step
  # (« Note de test décrivant … ») : la recherche est un AND de sous-chaînes,
  # un terme d'une lettre comme « A » matcherait toutes les notes.
  Scenario: La recherche allume les notes correspondantes
    Given a zettel titled {'Photosynthèse'} exists
    And a zettel titled {'Mitochondrie'} exists
    When I search for {'Photosynthèse'} in the note list
    Then the search results show {'Photosynthèse'}
    And the constellation lights {1} node

  Scenario: Le tiroir remonté liste les notes du jardin
    Given a zettel titled {'Concept A'} exists
    And a zettel titled {'Concept B'} exists
    When I raise the explorer sheet
    Then the note list shows a tile titled {'Concept A'}
    And the note list shows a tile titled {'Concept B'}

  Scenario: La constellation se zoome à la molette
    Given a zettel titled {'Concept A'} exists
    And a zettel titled {'Concept B'} exists
    And the zettel {'Concept A'} links to {'Concept B'}
    When I zoom into the graph
    Then the graph viewport scale increases
