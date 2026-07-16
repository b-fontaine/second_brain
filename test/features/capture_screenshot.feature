Feature: Image seeding with OCR through the sowing preview
  As a knowledge worker
  I want to import a screenshot and review its recognized text before sowing
  So that visual content becomes drafts in the nursery

  Background:
    Given the app is running with a configured vault
    And the local AI model is available
    And the local OCR engine is available

  Scenario: Importer une image reconnaît son texte vers l'aperçu avant semis
    When I tap the seed button
    And I choose to add a file
    And I import the image file {'diapositive_conference.png'}
    Then the seed preview shows the detected type {'Image'}
    And the seed preview text contains {'Texte reconnu sur la diapositive'}

  Scenario: Semer une image océrisée dépose un brouillon en pépinière
    Given the OCR engine reads {'Croquis du plan de rotation des cultures'}
    When I tap the seed button
    And I choose to add a file
    And I import the image file {'plan_rotation.png'}
    And I sow the seed preview
    Then the explorer confirms the seeding
    And the inbox contains {1} pending item
    When I open the nursery from the explorer pill
    Then the nursery shows the seedling titled {'Croquis du plan de rotation des cultures'}
