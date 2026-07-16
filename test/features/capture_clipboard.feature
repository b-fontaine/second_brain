Feature: Clipboard seeding through the sowing preview
  As a knowledge worker
  I want to paste copied content and review it before sowing
  So that raw content becomes an enriched draft in the nursery

  Background:
    Given the app is running with a configured vault
    And the local AI model is available

  Scenario: Coller ouvre l'aperçu avant semis avec le texte détecté
    When I tap the seed button
    And I choose to paste
    Then the seed preview shows the detected type {'Texte'}
    And the seed preview text contains {'notes atomiques'}

  Scenario: Semer le texte collé dépose un brouillon en pépinière
    Given the clipboard contains a note about {'les jardins partagés'}
    When I tap the seed button
    And I choose to paste
    Then the seed preview proposes the title {'Note copiée sur les jardins partagés'}
    When I sow the seed preview
    Then the explorer confirms the seeding
    And the inbox contains {1} pending item
    When I open the nursery from the explorer pill
    Then the nursery shows the seedling titled {'Note copiée sur les jardins partagés'}

  Scenario: L'IA locale propose un titre et une parcelle sur l'aperçu
    Given the local AI proposes the title {'Semis sous serre froide'} and the parcelle {'serre'}
    When I tap the seed button
    And I choose to paste
    Then the seed preview proposes the title {'Semis sous serre froide'}
    And I see {'serre'} text
    When I sow the seed preview
    And I open the nursery from the explorer pill
    Then the nursery shows the seedling titled {'Semis sous serre froide'}
    And I see {'serre'} text
