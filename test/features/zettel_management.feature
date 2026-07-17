Feature: Zettelkasten note management
  As a knowledge worker
  I want atomic, uniquely identified, linked notes
  So that my knowledge base follows the Zettelkasten method

  Background:
    Given the app is running with a configured vault

  Scenario: Creating a new zettel assigns a timestamp id
    When I tap the new note button
    And I enter {'Ma première idée'} as the note title
    And I enter {'Une idée atomique par note.'} as the note body
    And I save the note
    Then a zettel exists with title {'Ma première idée'}
    And the zettel has a unique timestamp id
    And the zettel is stored as a markdown file with frontmatter

  Scenario: Linking two zettels with a wikilink
    Given a zettel titled {'Concept A'} exists
    And a zettel titled {'Concept B'} exists
    When I open the zettel titled {'Concept A'}
    And I add a wikilink to {'Concept B'} in the body
    And I save the note
    Then the zettel {'Concept A'} links to {'Concept B'}
    And the zettel {'Concept B'} shows {'Concept A'} as a backlink

  Scenario: Browsing zettels from the home list
    Given a zettel titled {'Concept A'} exists
    When I search for {'Concept A'} in the note list
    And I open the zettel titled {'Concept A'}
    Then I see the note reading panel with title {'Concept A'}

  Scenario: Captured content lands in the inbox first
    Given a raw capture {'Texte brut capturé'} was ingested
    Then the inbox contains {1} pending item

  # Chantier 4 (plan Serre) : la note comme carrefour — mini-constellation
  # 1-hop en tête de lecture, section « Racines » (liens entrants/sortants),
  # section « Pollinisation » (suggestions RAG locales) avec action Tisser.
  Scenario: Une note carrefour montre sa racine sortante et sa mini-constellation
    Given a zettel titled {'Racine mère'} exists
    And a zettel titled {'Feuille fille'} exists
    And the zettel {'Racine mère'} links to {'Feuille fille'}
    When I open the zettel titled {'Racine mère'}
    Then the note shows its mini constellation
    And the roots section lists {'Feuille fille'} as an outgoing link

  Scenario: Une note carrefour montre sa racine entrante
    Given a zettel titled {'Racine mère'} exists
    And a zettel titled {'Feuille fille'} exists
    And the zettel {'Racine mère'} links to {'Feuille fille'}
    When I open the zettel titled {'Feuille fille'}
    Then the roots section lists {'Racine mère'} as an incoming link

  # En BDD l'index RAG répond par la voie mots-clés (pas de modèle
  # d'embeddings) : deux notes au contenu proche suffisent à polliniser.
  Scenario: Tisser une pollinisation ajoute le wikilink à la note
    Given a zettel titled {'Mémoire de travail'} exists with content about capacity limits
    And a zettel titled {'Attention sélective'} exists with content about capacity limits
    When I open the zettel titled {'Mémoire de travail'}
    Then the pollination section suggests {'Attention sélective'}
    When I weave the pollination suggestion {'Attention sélective'}
    Then the roots section lists {'Attention sélective'} as an outgoing link
    And the zettel {'Mémoire de travail'} links to {'Attention sélective'}

  # Le debounce du bandeau fleur est pompé explicitement via la constante
  # publique ZettelEditPage.pollinationDebounce (jamais de temps réel).
  Scenario: La fleur suggère de tisser pendant la frappe
    Given a zettel titled {'Mémoire de travail'} exists with content about capacity limits
    When I tap the new note button
    And I enter {'Les limites de capacité de la mémoire'} as the note body
    And the pollination debounce elapses
    Then the flower banner suggests weaving {'Mémoire de travail'}
