Feature: Clipboard capture with AI assistant
  As a knowledge worker
  I want to paste copied content and let a local AI assistant file it
  So that raw content becomes clean atomic zettels

  Background:
    Given the app is running with a configured vault
    And the local AI model is available

  Scenario: Pasting text opens the capture assistant
    When I tap the capture button
    And I choose the clipboard capture mode
    Then the clipboard content is shown as capture source

  Scenario: The assistant proposes atomic zettels from pasted text
    Given the clipboard contains a long article about {'la mémoire de travail'}
    When I run the capture assistant on the clipboard content
    Then the assistant proposes at least {1} zettel draft
    And each draft has a title, a body and suggested tags
    And each draft suggests links to existing related zettels

  Scenario: Accepting a draft saves it to the zettelkasten
    Given the capture assistant proposed a draft titled {'Mémoire de travail'}
    When I accept the draft
    Then a zettel exists with title {'Mémoire de travail'}
    And the draft references the original capture as source
