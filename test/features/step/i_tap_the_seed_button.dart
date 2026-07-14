import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/assistant/data/datasources/vault_rag_index.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';

import 'bdd_world.dart';
import 'fakes/capture_live_fake_transcription_service.dart';

/// Usage: I tap the seed button
///
/// Taps the central « Semer » button of the shell (compact layout in tests —
/// 800x600 < 840 dp — so the button overflows the bottom bar) and asserts
/// the speed-dial opens with its three seeding chips.
///
/// Before opening, swaps the world's transcription fake for its
/// live-dictation variant: the `TranscriptionService` lazy singleton is
/// instantiated when a dial chip pushes the capture flow (the CaptureBloc
/// factory resolves it), so the swap must happen before any chip is tapped
/// (see [CaptureLiveFakeTranscriptionService]).
Future<void> iTapTheSeedButton(WidgetTester tester) async {
  if (fakeTranscriptionService is! CaptureLiveFakeTranscriptionService) {
    fakeTranscriptionService = CaptureLiveFakeTranscriptionService.from(
      fakeTranscriptionService,
    );
  }
  // The singleton may already have been instantiated with the base fake by
  // an earlier step of the scenario (the DI closure reads the world global
  // at instantiation time). Re-register so the capture flow pushed by a
  // chip binds to the live fake.
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
        'fake; something instantiated it before the seed dial opened',
  );

  // The capture flow instantiates the `VaultRagIndex` singleton, which
  // subscribes to the vault-change stream INSIDE this test's FakeAsync
  // zone. Dispose it before the test's zone dies: otherwise the NEXT
  // scenario's `getIt.reset()` closes that broadcast stream and waits
  // forever (real time) for a done event that the dead zone can never
  // deliver — every scenario following a capture scenario would hang.
  addTearDown(() async {
    if (getIt.isRegistered<VaultRagIndex>()) {
      await getIt.unregister<VaultRagIndex>();
    }
  });

  final seedButton = find.byKey(const Key('seed-button'));
  expect(
    seedButton,
    findsOneWidget,
    reason: 'The central « Semer » button should be visible in the shell',
  );
  await tester.tap(seedButton);
  await tester.pumpAndSettle();

  // The speed-dial is open with its three seeding entries.
  for (final chip in const ['Dicter', 'Coller', 'Ajouter un fichier']) {
    expect(
      find.text(chip),
      findsOneWidget,
      reason: 'The seed dial should offer the « $chip » entry',
    );
  }
}
