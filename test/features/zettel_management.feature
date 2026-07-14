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
