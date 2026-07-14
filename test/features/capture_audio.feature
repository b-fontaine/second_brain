Feature: Audio capture with transcription assistant
  As a knowledge worker
  I want to import an audio recording and get a clean transcript
  So that spoken ideas become zettels

  Background:
    Given the app is running with a configured vault
    And the local AI model is available
    And the local transcription engine is available

  Scenario: Importing an audio file produces a transcript
    When I tap the seed button
    And I choose to add a file
    And I import the audio file {'meeting.m4a'}
    Then a transcript is produced
    And the transcript is shown for review

  Scenario: The assistant turns a transcript into zettel drafts
    Given a transcript of an audio note about {'les boucles de rétroaction'}
    When I run the capture assistant on the transcript
    Then the assistant proposes at least {1} zettel draft
    And each draft has a title, a body and suggested tags
