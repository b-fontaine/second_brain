Feature: Dictation seeding straight to the nursery
  As a knowledge worker
  I want to dictate a note and have it sown when I stop
  So that spoken ideas land as drafts in the nursery

  Background:
    Given the app is running with a configured vault
    And the local AI model is available
    And the local transcription engine is available

  Scenario: Dicter affiche la transcription en direct
    When I tap the seed button
    And I choose to dictate
    And I speak {'ceci est une note dictée'}
    Then the transcript contains {'ceci est une note dictée'}

  Scenario: Arrêter la dictée sème le brouillon en pépinière
    When I tap the seed button
    And I choose to dictate
    And I speak {'penser à pailler les fraisiers avant les gelées'}
    And I stop dictating
    Then the explorer confirms the seeding
    And the inbox contains {1} pending item
    When I open the nursery from the explorer pill
    Then the nursery shows the seedling titled {'penser à pailler les fraisiers avant les gelées'}
