Feature: App initialization with a remote git repository
  As a knowledge worker
  I want to configure a remote git repository on first launch
  So that my Zettelkasten is synchronized across devices

  Scenario: First launch shows the setup wizard
    Given the app is running for the first time
    Then I see {'Bienvenue dans Second Brain'} text
    And I see {'Configurer la synchronisation'} text

  Scenario: Configuring a remote repository with a token
    Given the app is running for the first time
    When I enter {'https://github.com/user/zettelkasten.git'} into the repository url field
    And I enter {'ghp_token123'} into the access token field
    And I tap {'Cloner et démarrer'} button
    Then the repository is cloned locally
    And I see the empty zettelkasten home screen

  Scenario: Skipping remote configuration works offline-only
    Given the app is running for the first time
    When I tap {'Continuer sans synchronisation'} button
    Then a local vault is created
    And I see the empty zettelkasten home screen

  Scenario: Invalid repository url shows an error
    Given the app is running for the first time
    When I enter {'not-a-url'} into the repository url field
    And I tap {'Cloner et démarrer'} button
    Then I see {'URL de dépôt invalide'} text
