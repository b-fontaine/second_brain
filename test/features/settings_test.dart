// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/a_remote_repository_is_configured_at.dart';
import './step/i_open_the_settings_screen.dart';
import './step/i_enter_into_the_settings_token_field.dart';
import './step/i_tap_button.dart';
import './step/the_git_token_is_updated.dart';
import './step/i_see_text.dart';
import './step/the_remote_rejects_the_token.dart';
import './step/the_git_token_is_not_persisted.dart';

void main() {
  group('''Git synchronization settings''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await aRemoteRepositoryIsConfiguredAt(
          tester, 'https://github.com/user/notes.git');
    }

    testWidgets('''Updating the access token successfully''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheSettingsScreen(tester);
      await iEnterIntoTheSettingsTokenField(tester, 'new-token');
      await iTapButton(tester, 'Enregistrer');
      await theGitTokenIsUpdated(tester);
      await iSeeText(tester, 'Jeton mis à jour');
    });
    testWidgets('''An invalid token is rejected''', (tester) async {
      await bddSetUp(tester);
      await theRemoteRejectsTheToken(tester, 'bad-token');
      await iOpenTheSettingsScreen(tester);
      await iEnterIntoTheSettingsTokenField(tester, 'bad-token');
      await iTapButton(tester, 'Enregistrer');
      await iSeeText(tester, 'Jeton refusé par le dépôt distant');
      await theGitTokenIsNotPersisted(tester);
    });
  });
}
