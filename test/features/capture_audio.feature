Feature: Audio file seeding through the sowing preview
  As a knowledge worker
  I want to import an audio recording and review its transcript before sowing
  So that spoken ideas become drafts in the nursery

  Background:
    Given the app is running with a configured vault
    And the local AI model is available
    And the local transcription engine is available

  Scenario: Importer un fichier audio transcrit vers l'aperçu avant semis
    When I tap the seed button
    And I choose to add a file
    And I import the audio file {'reunion_hebdomadaire.m4a'}
    Then the seed preview shows the detected type {'Audio'}
    And the seed preview text contains {'Compte rendu de la réunion'}

  Scenario: Semer une transcription audio dépose un brouillon en pépinière
    Given the transcription engine returns {'Relevé vocal sur les ruches urbaines'}
    When I tap the seed button
    And I choose to add a file
    And I import the audio file {'ruches_urbaines.m4a'}
    And I sow the seed preview
    Then the explorer confirms the seeding
    And the inbox contains {1} pending item
    When I open the nursery from the explorer pill
    Then the nursery shows the seedling titled {'Relevé vocal sur les ruches urbaines'}
