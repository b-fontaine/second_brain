Feature: Offline-first with automatic git synchronization
  As a knowledge worker
  I want the app to work fully offline and sync when possible
  So that I never lose work and my devices stay consistent

  Background:
    Given the app is running with a configured vault
    And a remote repository is configured

  Scenario: Saving a note offline commits locally
    Given the device is offline
    When I create a zettel titled {'Note hors ligne'}
    Then the zettel is committed to the local repository
    And the sync status shows pending changes

  Scenario: Regaining connectivity triggers an automatic push
    Given the device is offline
    And I create a zettel titled {'Note hors ligne'}
    When the device comes back online
    Then the pending commits are pushed to the remote
    And the sync status shows up to date

  Scenario: Saving while online syncs immediately
    Given the device is online
    When I create a zettel titled {'Note en ligne'}
    Then the zettel is committed to the local repository
    And the pending commits are pushed to the remote
