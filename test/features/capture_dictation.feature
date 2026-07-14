Feature: Dictation capture with live transcription
  As a knowledge worker
  I want to dictate a note with my voice
  So that I can capture ideas hands-free

  Background:
    Given the app is running with a configured vault
    And the local AI model is available
    And the local transcription engine is available

  Scenario: Dictating produces a live transcript
    When I tap the seed button
    And I choose to dictate
    And I speak {'ceci est une note dictée'}
    And I stop dictating
    Then the transcript contains {'ceci est une note dictée'}

  Scenario: The assistant files the dictated transcript
    Given a dictated transcript about {'la revue de code'}
    When I run the capture assistant on the transcript
    Then the assistant proposes at least {1} zettel draft
