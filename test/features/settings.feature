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

  # Chantier 6 (plan Serre) : réglages en cartes — Synchronisation,
  # Jeton d'accès, Jardin (coffre + notes cultivées), Modèles.
  Scenario: Les réglages présentent le jardin en cartes
    Given a zettel titled {'Note du potager'} exists
    When I open the settings screen
    Then I see {'Synchronisation'} text
    And I see {'Jardin'} text
    And I see {'Notes cultivées'} text
    And I see {'1 note'} text
    And I see {'Modèles locaux'} text
    And I see {'Gérer les modèles'} text

  # Conflit résolu « local gagne » : copie distante sous conflicts/,
  # toast pédagogique du shell puis carte ambre dans les réglages.
  Scenario: Un conflit résolu s'affiche en carte ambre dans les réglages
    Given the last synchronization resolved {2} conflicts
    Then the conflict toast explains the conflicts folder
    When I open the settings screen
    Then the settings show the resolved conflict card
