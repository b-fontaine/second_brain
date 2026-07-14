Feature: Querying the knowledge base by prompt
  As a knowledge worker
  I want to ask questions in natural language, written or spoken
  So that I can retrieve knowledge from my zettelkasten

  Background:
    Given the app is running with a configured vault
    And the local AI model is available
    And a zettel titled {'Mémoire de travail'} exists with content about capacity limits

  Scenario: Asking a written question returns an answer with sources
    When I open the assistant chat
    And I ask {'Que sais-je sur la mémoire de travail ?'}
    Then the assistant answers using the zettelkasten content
    And the answer cites the zettel {'Mémoire de travail'} as source

  Scenario: Tapping a cited source opens the zettel
    Given the assistant answered citing {'Mémoire de travail'}
    When I tap the cited source {'Mémoire de travail'}
    Then I see the note reading panel with title {'Mémoire de travail'}

  Scenario: Asking a question by voice
    Given the local transcription engine is available
    When I open the assistant chat
    And I ask by voice {'Que sais-je sur la mémoire de travail ?'}
    Then the assistant answers using the zettelkasten content
