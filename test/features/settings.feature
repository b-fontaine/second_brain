Feature: Git synchronization settings
  As a knowledge worker
  I want to renew my git access token from a settings screen
  So that an expired token never locks me out of synchronization

  Background:
    Given the app is running with a configured vault
    And a remote repository is configured at {'https://github.com/user/notes.git'}

  Scenario: Updating the access token successfully
    When I open the settings screen
    And I enter {'new-token'} into the settings token field
    And I tap {'Enregistrer'} button
    Then the git token is updated
    And I see {'Jeton mis à jour'} text

  Scenario: An invalid token is rejected
    Given the remote rejects the token {'bad-token'}
    When I open the settings screen
    And I enter {'bad-token'} into the settings token field
    And I tap {'Enregistrer'} button
    Then I see {'Jeton refusé par le dépôt distant'} text
    And the git token is not persisted
