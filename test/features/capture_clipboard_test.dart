// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/the_local_ai_model_is_available.dart';
import './step/i_tap_the_capture_button.dart';
import './step/i_choose_the_clipboard_capture_mode.dart';
import './step/the_clipboard_content_is_shown_as_capture_source.dart';
import './step/the_clipboard_contains_a_long_article_about.dart';
import './step/i_run_the_capture_assistant_on_the_clipboard_content.dart';
import './step/the_assistant_proposes_at_least_zettel_draft.dart';
import './step/each_draft_has_a_title_a_body_and_suggested_tags.dart';
import './step/each_draft_suggests_links_to_existing_related_zettels.dart';
import './step/the_capture_assistant_proposed_a_draft_titled.dart';
import './step/i_accept_the_draft.dart';
import './step/a_zettel_exists_with_title.dart';
import './step/the_draft_references_the_original_capture_as_source.dart';

void main() {
  group('''Clipboard capture with AI assistant''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await theLocalAiModelIsAvailable(tester);
    }

    testWidgets('''Pasting text opens the capture assistant''', (tester) async {
      await bddSetUp(tester);
      await iTapTheCaptureButton(tester);
      await iChooseTheClipboardCaptureMode(tester);
      await theClipboardContentIsShownAsCaptureSource(tester);
    });
    testWidgets('''The assistant proposes atomic zettels from pasted text''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theClipboardContainsALongArticleAbout(
        tester,
        'la mémoire de travail',
      );
      await iRunTheCaptureAssistantOnTheClipboardContent(tester);
      await theAssistantProposesAtLeastZettelDraft(tester, 1);
      await eachDraftHasATitleABodyAndSuggestedTags(tester);
      await eachDraftSuggestsLinksToExistingRelatedZettels(tester);
    });
    testWidgets('''Accepting a draft saves it to the zettelkasten''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theCaptureAssistantProposedADraftTitled(
        tester,
        'Mémoire de travail',
      );
      await iAcceptTheDraft(tester);
      await aZettelExistsWithTitle(tester, 'Mémoire de travail');
      await theDraftReferencesTheOriginalCaptureAsSource(tester);
    });
  });
}
