Feature: Screenshot capture with OCR assistant
  As a knowledge worker
  I want to import a screenshot and extract its text
  So that visual content becomes searchable zettels

  Background:
    Given the app is running with a configured vault
    And the local AI model is available
    And the local OCR engine is available

  Scenario: Importing a screenshot extracts its text
    When I tap the seed button
    And I choose to add a file
    And I import the image file {'slide.png'}
    Then the recognized text is shown for review

  Scenario: The assistant turns OCR text into zettel drafts
    Given an OCR result about {'l architecture hexagonale'}
    When I run the capture assistant on the OCR text
    Then the assistant proposes at least {1} zettel draft
    And each draft has a title, a body and suggested tags
