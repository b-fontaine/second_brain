// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/the_local_ai_model_is_available.dart';
import './step/the_local_ocr_engine_is_available.dart';
import './step/i_tap_the_seed_button.dart';
import './step/i_choose_to_add_a_file.dart';
import './step/i_import_the_image_file.dart';
import './step/the_recognized_text_is_shown_for_review.dart';
import './step/an_ocr_result_about.dart';
import './step/i_run_the_capture_assistant_on_the_ocr_text.dart';
import './step/the_assistant_proposes_at_least_zettel_draft.dart';
import './step/each_draft_has_a_title_a_body_and_suggested_tags.dart';

void main() {
  group('''Screenshot capture with OCR assistant''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await theLocalAiModelIsAvailable(tester);
      await theLocalOcrEngineIsAvailable(tester);
    }

    testWidgets('''Importing a screenshot extracts its text''', (tester) async {
      await bddSetUp(tester);
      await iTapTheSeedButton(tester);
      await iChooseToAddAFile(tester);
      await iImportTheImageFile(tester, 'slide.png');
      await theRecognizedTextIsShownForReview(tester);
    });
    testWidgets('''The assistant turns OCR text into zettel drafts''',
        (tester) async {
      await bddSetUp(tester);
      await anOcrResultAbout(tester, 'l architecture hexagonale');
      await iRunTheCaptureAssistantOnTheOcrText(tester);
      await theAssistantProposesAtLeastZettelDraft(tester, 1);
      await eachDraftHasATitleABodyAndSuggestedTags(tester);
    });
  });
}
