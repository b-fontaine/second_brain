import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/assistant/data/datasources/vault_rag_index.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';

import 'bdd_world.dart';
import 'fakes/capture_live_fake_transcription_service.dart';

/// Usage: I tap the capture button
///
/// Opens the "Capturer" tab from the shell navigation (compact layout in
/// tests — 800x600 < 840 dp — so the destination lives in the bottom
/// [NavigationBar]; its icon is unique while its label also titles pages).
///
/// Before navigating, swaps the world's transcription fake for its
/// live-dictation variant: the `TranscriptionService` lazy singleton is
/// instantiated when the capture page first builds, so the swap must happen
/// before this first navigation (see [CaptureLiveFakeTranscriptionService]).
Future<void> iTapTheCaptureButton(WidgetTester tester) async {
  if (fakeTranscriptionService is! CaptureLiveFakeTranscriptionService) {
    fakeTranscriptionService = CaptureLiveFakeTranscriptionService.from(
      fakeTranscriptionService,
    );
  }
  // The singleton may already have been instantiated with the base fake: a
  // stray first frame can build the capture page during pumpApp when the
  // PREVIOUS scenario ended there (the process-global router restores its
  // last location until the async redirect back to '/' resolves).
  // Re-register so the capture page created below binds to the live fake.
  if (getIt.isRegistered<TranscriptionService>()) {
    await getIt.unregister<TranscriptionService>();
  }
  getIt.registerLazySingleton<TranscriptionService>(
    () => fakeTranscriptionService,
  );
  expect(
    identical(getIt<TranscriptionService>(), fakeTranscriptionService),
    isTrue,
    reason:
        'The TranscriptionService singleton must be the live-dictation '
        'fake; something instantiated it before the capture page opened',
  );

  // Opening the capture page instantiates the `VaultRagIndex` singleton,
  // which subscribes to the vault-change stream INSIDE this test's FakeAsync
  // zone. Dispose it before the test's zone dies: otherwise the NEXT
  // scenario's `getIt.reset()` closes that broadcast stream and waits
  // forever (real time) for a done event that the dead zone can never
  // deliver — every scenario following a capture scenario would hang.
  addTearDown(() async {
    if (getIt.isRegistered<VaultRagIndex>()) {
      await getIt.unregister<VaultRagIndex>();
    }
  });

  final captureDestination = find.byIcon(Icons.add_box_outlined);
  expect(
    captureDestination,
    findsOneWidget,
    reason: 'The Capturer navigation destination should be visible',
  );
  await tester.tap(captureDestination);
  await tester.pumpAndSettle();

  // The capture mode-selection screen is displayed.
  expect(find.text('Que souhaitez-vous capturer ?'), findsOneWidget);
}
