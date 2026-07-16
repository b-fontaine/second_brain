Feature: Nursery review of the sown drafts
  As a knowledge worker
  I want to review the drafts waiting in the nursery
  So that each sowing becomes a note or goes to compost

  Background:
    Given the app is running with a configured vault

  Scenario: La pépinière liste les semis en attente de validation
    Given a sown seedling titled {'Arrosage des cultures hydroponiques'} with the parcelle {'hydroponie'}
    And a sown seedling titled {'Greffe des agrumes en hiver'} with the parcelle {'verger'}
    When I open the nursery from the explorer pill
    Then I see {'2 brouillons à valider — repiquez-les en notes ou compostez-les.'} text
    And the nursery shows the seedling titled {'Arrosage des cultures hydroponiques'}
    And the nursery shows the seedling titled {'Greffe des agrumes en hiver'}
    And I see {'hydroponie'} text

  Scenario: Repiquer un semis crée la note au jardin
    Given a sown seedling titled {'Paillage du potager en été'} with the parcelle {'potager'}
    When I open the nursery from the explorer pill
    And I transplant the seedling titled {'Paillage du potager en été'}
    Then I see {'Repiqué au jardin — note « Paillage du potager en été » créée.'} text
    And a zettel exists with title {'Paillage du potager en été'}
    And the draft references the original capture as source
    And the inbox contains {0} pending item

  Scenario: Composter un semis supprime le brouillon
    Given a sown seedling titled {'Taille des rosiers anciens'} with the parcelle {'roseraie'}
    When I open the nursery from the explorer pill
    And I compost the seedling titled {'Taille des rosiers anciens'}
    Then I see {'Semis composté — brouillon supprimé.'} text
    And the inbox contains {0} pending item
    And no zettel exists with title {'Taille des rosiers anciens'}

  Scenario: La pastille semis de l'explorateur suit le compte
    Given a sown seedling titled {'Semis de tomates cerises'} with the parcelle {'potager'}
    Then the explorer seedling pill shows {'1 semis'}
    When I open the nursery from the explorer pill
    And I transplant the seedling titled {'Semis de tomates cerises'}
    And I return to the explorer
    Then the explorer seedling pill is hidden

  Scenario: La pépinière vide invite à semer
    When I open the empty nursery
    Then I see {'La pépinière est vide'} text
    When I tap {'Semer'} button
    Then I see {'Dicter'} text
    And I see {'Coller'} text
