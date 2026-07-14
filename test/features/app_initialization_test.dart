// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_for_the_first_time.dart';
import './step/i_see_text.dart';
import './step/i_enter_into_the_repository_url_field.dart';
import './step/i_enter_into_the_access_token_field.dart';
import './step/i_tap_button.dart';
import './step/the_repository_is_cloned_locally.dart';
import './step/i_see_the_empty_zettelkasten_home_screen.dart';
import './step/a_local_vault_is_created.dart';

void main() {
  group('''App initialization with a remote git repository''', () {
    testWidgets('''First launch shows the setup wizard''', (tester) async {
      await theAppIsRunningForTheFirstTime(tester);
      await iSeeText(tester, 'Bienvenue dans Second Brain');
      await iSeeText(tester, 'Configurer la synchronisation');
    });
    testWidgets('''Configuring a remote repository with a token''', (
      tester,
    ) async {
      await theAppIsRunningForTheFirstTime(tester);
      await iEnterIntoTheRepositoryUrlField(
        tester,
        'https://github.com/user/zettelkasten.git',
      );
      await iEnterIntoTheAccessTokenField(tester, 'ghp_token123');
      await iTapButton(tester, 'Cloner et démarrer');
      await theRepositoryIsClonedLocally(tester);
      await iSeeTheEmptyZettelkastenHomeScreen(tester);
    });
    testWidgets('''Skipping remote configuration works offline-only''', (
      tester,
    ) async {
      await theAppIsRunningForTheFirstTime(tester);
      await iTapButton(tester, 'Continuer sans synchronisation');
      await aLocalVaultIsCreated(tester);
      await iSeeTheEmptyZettelkastenHomeScreen(tester);
    });
    testWidgets('''Invalid repository url shows an error''', (tester) async {
      await theAppIsRunningForTheFirstTime(tester);
      await iEnterIntoTheRepositoryUrlField(tester, 'not-a-url');
      await iTapButton(tester, 'Cloner et démarrer');
      await iSeeText(tester, 'URL de dépôt invalide');
    });
  });
}
