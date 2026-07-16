/// Shared BDD world for every `test/features/*_test.dart` suite.
///
/// One call to [setUpWorld] per scenario resets `getIt`, creates a real
/// temporary vault on disk and registers the whole dependency graph of the
/// app WITHOUT `configureDependencies()` — real pure-Dart implementations
/// everywhere (repositories, use cases, blocs, RAG keyword index), and
/// controllable fakes at the native boundaries (see `fakes/`).
///
/// Steps then drive the REAL app ([pumpApp] pumps `SecondBrainApp` with the
/// real router) and script the outside world through the `fake*` globals.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:second_brain/app.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/core/router/app_router.dart';
import 'package:second_brain/core/services/clock.dart';
import 'package:second_brain/core/services/network_info.dart';
import 'package:second_brain/core/services/vault_locator.dart';
import 'package:second_brain/core/services/vault_write_notifier.dart';
import 'package:second_brain/features/assistant/data/datasources/rag_embeddings_gateway.dart';
import 'package:second_brain/features/assistant/data/datasources/vault_rag_index.dart';
import 'package:second_brain/features/assistant/data/repositories/gemma_assistant_repository.dart';
import 'package:second_brain/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:second_brain/features/assistant/domain/services/local_ai_service.dart';
import 'package:second_brain/features/assistant/presentation/bloc/chat_bloc.dart';
import 'package:second_brain/features/assistant/presentation/bloc/dictation_cubit.dart';
import 'package:second_brain/features/assistant/presentation/bloc/model_status_cubit.dart';
import 'package:second_brain/features/capture/domain/services/capture_intake.dart';
import 'package:second_brain/features/capture/domain/services/clipboard_service.dart';
import 'package:second_brain/features/capture/domain/services/ocr_service.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';
import 'package:second_brain/features/capture/domain/usecases/accept_draft.dart';
import 'package:second_brain/features/capture/domain/usecases/capture_from_clipboard.dart';
import 'package:second_brain/features/capture/domain/usecases/ensure_stt_model.dart';
import 'package:second_brain/features/capture/domain/usecases/process_capture.dart';
import 'package:second_brain/features/capture/domain/usecases/recognize_screenshot.dart';
import 'package:second_brain/features/capture/domain/usecases/start_dictation.dart';
import 'package:second_brain/features/capture/domain/usecases/stop_dictation.dart';
import 'package:second_brain/features/capture/domain/usecases/transcribe_audio_file.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:second_brain/features/capture/presentation/bloc/pepiniere_cubit.dart';
import 'package:second_brain/features/capture/presentation/bloc/seed_intake_cubit.dart';
import 'package:second_brain/features/capture/presentation/pages/seed_preview_page.dart';
import 'package:second_brain/features/explorer/presentation/bloc/seedling_count_cubit.dart';
import 'package:second_brain/features/graph/domain/usecases/suggest_related_notes.dart';
import 'package:second_brain/features/graph/domain/usecases/watch_vault.dart';
import 'package:second_brain/features/graph/presentation/bloc/graph_cubit.dart';
import 'package:second_brain/features/setup/data/datasources/setup_local_data_source.dart';
import 'package:second_brain/features/setup/data/models/vault_config_model.dart';
import 'package:second_brain/features/setup/data/repositories/setup_repository_impl.dart';
import 'package:second_brain/features/setup/domain/repositories/setup_repository.dart';
import 'package:second_brain/features/setup/domain/usecases/configure_local_only.dart';
import 'package:second_brain/features/setup/domain/usecases/configure_with_remote.dart';
import 'package:second_brain/features/setup/domain/usecases/get_vault_config.dart';
import 'package:second_brain/features/setup/presentation/bloc/setup_bloc.dart';
import 'package:second_brain/features/sync/application/sync_orchestrator.dart';
import 'package:second_brain/features/sync/data/services/pull_change_notifier.dart';
import 'package:second_brain/features/sync/domain/repositories/git_sync_repository.dart';
import 'package:second_brain/features/sync/domain/usecases/force_synchronize.dart';
import 'package:second_brain/features/sync/domain/usecases/get_sync_status.dart';
import 'package:second_brain/features/sync/domain/usecases/test_remote_connection.dart';
import 'package:second_brain/features/sync/domain/usecases/update_git_token.dart';
import 'package:second_brain/features/sync/domain/usecases/watch_sync_status.dart';
import 'package:second_brain/features/sync/presentation/bloc/settings_cubit.dart';
import 'package:second_brain/features/sync/presentation/bloc/sync_status_cubit.dart';
import 'package:second_brain/features/zettel/data/datasources/vault_data_source.dart'
    show VaultDataSource;
import 'package:second_brain/features/zettel/data/repositories/inbox_repository_impl.dart';
import 'package:second_brain/features/zettel/data/repositories/zettel_repository_impl.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/inbox_repository.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';
import 'package:second_brain/features/zettel/domain/usecases/create_zettel.dart';
import 'package:second_brain/features/zettel/domain/usecases/delete_zettel.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_all_zettels.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_backlinks.dart';
import 'package:second_brain/features/zettel/domain/usecases/get_zettel_by_id.dart';
import 'package:second_brain/features/zettel/domain/usecases/search_zettels.dart';
import 'package:second_brain/features/zettel/domain/usecases/transplant_seedling.dart';
import 'package:second_brain/features/zettel/domain/usecases/update_zettel.dart';
import 'package:second_brain/features/zettel/presentation/bloc/notes_list/notes_list_bloc.dart';
import 'package:second_brain/features/zettel/presentation/bloc/zettel_detail/zettel_detail_cubit.dart';
import 'package:second_brain/features/zettel/presentation/bloc/zettel_edit/zettel_edit_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_clipboard_service.dart';
import 'fakes/fake_clock.dart';
import 'fakes/fake_git_sync_repository.dart';
import 'fakes/fake_local_ai_service.dart';
import 'fakes/fake_network_info.dart';
import 'fakes/fake_ocr_service.dart';
import 'fakes/fake_rag_embeddings_gateway.dart';
import 'fakes/fake_setup_local_data_source.dart';
import 'fakes/fake_transcription_service.dart';
import 'fakes/fake_vault_locator.dart';
import 'fakes/sync_file_vault_data_source.dart';

export 'package:second_brain/core/di/injection.dart' show getIt;

export 'fakes/fake_clipboard_service.dart';
export 'fakes/fake_clock.dart';
export 'fakes/fake_git_sync_repository.dart';
export 'fakes/fake_local_ai_service.dart';
export 'fakes/fake_network_info.dart';
export 'fakes/fake_ocr_service.dart';
export 'fakes/fake_rag_embeddings_gateway.dart';
export 'fakes/fake_setup_local_data_source.dart';
export 'fakes/fake_transcription_service.dart';
export 'fakes/fake_vault_locator.dart';
export 'fakes/sync_file_vault_data_source.dart';

// --- World state (reassigned on every setUpWorld) ---------------------------

/// Root of the real temporary vault on disk (`zettel/`, `inbox/`, `assets/`).
late Directory bddVaultDir;

late FakeClock fakeClock;
late FakeVaultLocator fakeVaultLocator;
late FakeNetworkInfo fakeNetworkInfo;
late FakeGitSyncRepository fakeGitSyncRepository;
late FakeLocalAiService fakeLocalAiService;
late FakeTranscriptionService fakeTranscriptionService;
late FakeOcrService fakeOcrService;
late FakeClipboardService fakeClipboardService;
late FakeSetupLocalDataSource fakeSetupLocalDataSource;

/// Last zettel referenced by a step (e.g. "a zettel exists with title X"),
/// so follow-up assertions like "the zettel has a unique timestamp id"
/// know which note they are about.
Zettel? worldLastZettel;

// --- Lifecycle ---------------------------------------------------------------

/// Resets the DI container, creates a fresh temp vault and registers the
/// full app dependency graph (real implementations + fakes above).
///
/// [configured] controls the onboarding state: when true, the vault path is
/// already published (locator + setup config) and the app boots on the home
/// screen; when false, the router redirects to `/setup` (first launch).
Future<void> setUpWorld(WidgetTester tester, {bool configured = true}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await getIt.reset();

  // Synchronous IO on purpose: real *async* dart:io calls never complete
  // inside the FakeAsync zone of testWidgets (they wait on event-loop IO
  // events that nothing pumps) — the whole vault layer of this world
  // therefore uses sync IO (see [SyncFileVaultDataSource]).
  bddVaultDir = Directory.systemTemp.createTempSync('bdd_vault');
  addTearDown(() {
    try {
      bddVaultDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Best-effort cleanup of the temp vault.
    }
  });

  worldLastZettel = null;
  fakeClock = FakeClock(DateTime(2026, 6, 1, 9, 0, 0));
  fakeVaultLocator = FakeVaultLocator(
    path: configured ? bddVaultDir.path : null,
  );
  fakeNetworkInfo = FakeNetworkInfo();
  fakeGitSyncRepository = FakeGitSyncRepository(
    fakeVaultLocator,
    fakeNetworkInfo,
  );
  fakeLocalAiService = FakeLocalAiService();
  fakeTranscriptionService = FakeTranscriptionService();
  fakeOcrService = FakeOcrService();
  fakeClipboardService = FakeClipboardService();
  fakeSetupLocalDataSource = FakeSetupLocalDataSource(
    vaultPath: bddVaultDir.path,
    config: configured ? VaultConfigModel(vaultPath: bddVaultDir.path) : null,
  );

  if (configured) {
    for (final folder in const ['zettel', 'inbox', 'assets']) {
      Directory(p.join(bddVaultDir.path, folder)).createSync(recursive: true);
    }
  }

  _registerDependencies();
}

/// Pumps the real app (real router, real pages) and settles.
///
/// The router's global redirect calls `getIt<SetupRepository>().getConfig()`,
/// so the configured/unconfigured state chosen in [setUpWorld] decides
/// whether this lands on the home screen or on `/setup`.
Future<void> pumpApp(WidgetTester tester) async {
  // `appRouter` is a process-wide singleton: send it back to the initial
  // location so a scenario never starts where the previous one ended.
  appRouter.go(AppRoutes.explorer);
  await tester.pumpWidget(const SecondBrainApp());
  await tester.pumpAndSettle();
}

// --- World helpers -----------------------------------------------------------

/// Creates a zettel through the real repository (markdown file on disk),
/// advancing [fakeClock] by one second first so ids never collide.
Future<Zettel> worldCreateZettel(
  String title, {
  String body = '',
  List<String> tags = const [],
  String? source,
}) async {
  fakeClock.advance();
  final result = await getIt<ZettelRepository>().createZettel(
    title: title,
    body: body,
    tags: tags,
    source: source,
  );
  final zettel = result.getOrElse(
    (failure) => throw StateError('worldCreateZettel: ${failure.message}'),
  );
  worldLastZettel = zettel;
  return zettel;
}

/// The vault zettel whose (trimmed) title equals [title], or null.
Future<Zettel?> worldGetZettelByTitle(String title) async {
  final result = await getIt<ZettelRepository>().getAllZettels();
  final zettels = result.getOrElse(
    (failure) => throw StateError('worldGetZettelByTitle: ${failure.message}'),
  );
  for (final zettel in zettels) {
    if (zettel.title.trim() == title.trim()) return zettel;
  }
  return null;
}

/// Like [worldGetZettelByTitle] but fails the test when the note is absent.
Future<Zettel> worldRequireZettelByTitle(String title) async {
  final zettel = await worldGetZettelByTitle(title);
  if (zettel == null) {
    fail("No zettel titled '$title' in the vault");
  }
  worldLastZettel = zettel;
  return zettel;
}

/// Persists a pending capture in the real `inbox/` folder, advancing
/// [fakeClock] so item ids stay unique.
Future<InboxItem> worldAddInboxItem(
  String rawText, {
  CaptureType type = CaptureType.clipboard,
  String? assetPath,
  String? title,
  List<String> tags = const [],
}) async {
  fakeClock.advance();
  final item = InboxItem(
    id: ZettelId.fromDateTime(fakeClock.current).value,
    type: type,
    rawText: rawText,
    capturedAt: fakeClock.current,
    assetPath: assetPath,
    title: title,
    tags: tags,
  );
  final result = await getIt<InboxRepository>().addItem(item);
  return result.getOrElse(
    (failure) => throw StateError('worldAddInboxItem: ${failure.message}'),
  );
}

/// Emulates the outcome of the seed dial's « Ajouter un fichier » chip,
/// with [path] standing in for the native picker's answer: closes the dial
/// when it is open, then pushes the « aperçu avant semis » preview primed
/// with a [FileSeedSource] — exactly what `seedByFile` does after
/// `pickSeedFilePath` returns (the picker itself hard-calls
/// `file_selector.openFile` and cannot run in a widget test).
Future<void> worldOpenSeedPreview(WidgetTester tester, String path) async {
  final scrim = find.byKey(const Key('seed-dial-scrim'));
  if (scrim.evaluate().isNotEmpty) {
    // Same dismissal as a tap on the barrier (a chip tap would dismiss the
    // dial the same way before acting).
    tester.widget<ModalBarrier>(scrim).onDismiss!();
    await tester.pumpAndSettle();
  }
  // The chips resolve the ROOT navigator (the preview must cover the whole
  // shell); the first Navigator in tree order is the root one.
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SeedPreviewPage(source: FileSeedSource(path)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// --- DI registration ---------------------------------------------------------

/// Manual mirror of `injection.config.dart` with fakes at every native
/// boundary. No plugin (path_provider, secure storage, connectivity,
/// flutter_gemma, git2dart, sherpa...) is ever touched.
void _registerDependencies() {
  // Core services.
  getIt
    ..registerLazySingleton<Clock>(() => fakeClock)
    ..registerLazySingleton<VaultLocator>(() => fakeVaultLocator)
    ..registerLazySingleton<NetworkInfo>(
      () => fakeNetworkInfo,
      dispose: (info) => (info as FakeNetworkInfo).dispose(),
    );

  // Zettel: real file-backed data layer on the temp vault.
  getIt
    // Sync-IO twin of FileVaultDataSource (async file IO deadlocks under
    // the FakeAsync test zone); real files, same naming and codecs.
    ..registerLazySingleton<VaultDataSource>(
      () => SyncFileVaultDataSource(getIt<VaultLocator>()),
    )
    ..registerLazySingleton<ZettelRepository>(
      () => ZettelRepositoryImpl(getIt<VaultDataSource>(), getIt<Clock>()),
      dispose: disposeZettelRepository,
    )
    ..registerLazySingleton<InboxRepository>(
      () => InboxRepositoryImpl(
        getIt<VaultDataSource>(),
        getIt<VaultWriteNotifier>(),
      ),
    )
    ..registerFactory<CreateZettel>(
      () => CreateZettel(getIt<ZettelRepository>()),
    )
    ..registerFactory<DeleteZettel>(
      () => DeleteZettel(getIt<ZettelRepository>()),
    )
    ..registerFactory<GetAllZettels>(
      () => GetAllZettels(getIt<ZettelRepository>()),
    )
    ..registerFactory<GetBacklinks>(
      () => GetBacklinks(getIt<ZettelRepository>()),
    )
    ..registerFactory<GetZettelById>(
      () => GetZettelById(getIt<ZettelRepository>()),
    )
    ..registerFactory<SearchZettels>(
      () => SearchZettels(getIt<ZettelRepository>()),
    )
    ..registerFactory<UpdateZettel>(
      () => UpdateZettel(getIt<ZettelRepository>()),
    )
    ..registerFactory<TransplantSeedling>(
      () => TransplantSeedling(getIt<CreateZettel>(), getIt<InboxRepository>()),
    )
    ..registerFactory<NotesListBloc>(
      () => NotesListBloc(
        getIt<GetAllZettels>(),
        getIt<SearchZettels>(),
        getIt<ZettelRepository>(),
      ),
    )
    ..registerFactory<ZettelDetailCubit>(
      () => ZettelDetailCubit(
        getIt<GetZettelById>(),
        getIt<GetBacklinks>(),
        getIt<DeleteZettel>(),
      ),
    )
    ..registerFactory<ZettelEditBloc>(
      () => ZettelEditBloc(
        getIt<CreateZettel>(),
        getIt<UpdateZettel>(),
        getIt<GetZettelById>(),
        getIt<TransplantSeedling>(),
      ),
    );

  // Graph.
  getIt
    ..registerFactory<WatchVault>(() => WatchVault(getIt<ZettelRepository>()))
    ..registerFactory<SuggestRelatedNotes>(
      () => SuggestRelatedNotes(
        getIt<ZettelRepository>(),
        getIt<VaultRagIndex>(),
      ),
    )
    ..registerFactory<GraphCubit>(
      () => GraphCubit(
        getIt<GetAllZettels>(),
        getIt<WatchVault>(),
        getIt<SuggestRelatedNotes>(),
      ),
    );

  // Explorer (fused surface).
  getIt.registerFactory<SeedlingCountCubit>(
    () => SeedlingCountCubit(
      getIt<InboxRepository>(),
      getIt<VaultWriteNotifier>(),
    ),
  );

  // Assistant: real repository + real keyword RAG index over the fake LLM.
  getIt
    ..registerLazySingleton<LocalAiService>(() => fakeLocalAiService)
    ..registerLazySingleton<RagEmbeddingsGateway>(FakeRagEmbeddingsGateway.new)
    ..registerLazySingleton<VaultRagIndex>(
      () => VaultRagIndex(
        getIt<ZettelRepository>(),
        getIt<RagEmbeddingsGateway>(),
      ),
      dispose: (index) => index.dispose(),
    )
    ..registerLazySingleton<AssistantRepository>(
      () => GemmaAssistantRepository(
        getIt<LocalAiService>(),
        getIt<VaultRagIndex>(),
        getIt<ZettelRepository>(),
      ),
    )
    ..registerFactory<ChatBloc>(() => ChatBloc(getIt<AssistantRepository>()))
    ..registerFactory<ModelStatusCubit>(
      () => ModelStatusCubit(getIt<AssistantRepository>()),
    )
    ..registerFactory<DictationCubit>(
      () => DictationCubit(getIt<TranscriptionService>()),
    );

  // Capture: fake extraction engines, real use cases and bloc.
  getIt
    ..registerLazySingleton<TranscriptionService>(
      () => fakeTranscriptionService,
    )
    ..registerLazySingleton<OcrService>(() => fakeOcrService)
    ..registerLazySingleton<ClipboardService>(() => fakeClipboardService)
    ..registerFactory<CaptureFromClipboard>(
      () => CaptureFromClipboard(getIt<ClipboardService>()),
    )
    ..registerFactory<TranscribeAudioFile>(
      () => TranscribeAudioFile(getIt<TranscriptionService>()),
    )
    ..registerFactory<RecognizeScreenshot>(
      () => RecognizeScreenshot(getIt<OcrService>()),
    )
    ..registerFactory<EnsureSttModel>(
      () => EnsureSttModel(getIt<TranscriptionService>()),
    )
    ..registerFactory<StartDictation>(
      () => StartDictation(getIt<TranscriptionService>()),
    )
    ..registerFactory<StopDictation>(
      () => StopDictation(getIt<TranscriptionService>()),
    )
    ..registerFactory<ProcessCapture>(
      () => ProcessCapture(
        getIt<InboxRepository>(),
        getIt<AssistantRepository>(),
        getIt<Clock>(),
      ),
    )
    ..registerFactory<AcceptDraft>(
      () => AcceptDraft(getIt<CreateZettel>(), getIt<InboxRepository>()),
    )
    ..registerFactory<CaptureBloc>(
      () => CaptureBloc(
        captureFromClipboard: getIt<CaptureFromClipboard>(),
        transcribeAudioFile: getIt<TranscribeAudioFile>(),
        recognizeScreenshot: getIt<RecognizeScreenshot>(),
        processCapture: getIt<ProcessCapture>(),
        acceptDraft: getIt<AcceptDraft>(),
        startDictation: getIt<StartDictation>(),
        stopDictation: getIt<StopDictation>(),
        ensureSttModel: getIt<EnsureSttModel>(),
        captureIntake: getIt<CaptureIntake>(),
      ),
    )
    // Seeding intake (aperçu avant semis): real service over the fakes.
    ..registerLazySingleton<CaptureIntake>(
      () => CaptureIntake(
        getIt<RecognizeScreenshot>(),
        getIt<TranscribeAudioFile>(),
        getIt<LocalAiService>(),
        getIt<InboxRepository>(),
        getIt<Clock>(),
      ),
    )
    ..registerFactory<SeedIntakeCubit>(
      () => SeedIntakeCubit(
        getIt<CaptureIntake>(),
        getIt<CaptureFromClipboard>(),
        getIt<EnsureSttModel>(),
      ),
    )
    // Pépinière (nursery review of the pending captures).
    ..registerFactory<PepiniereCubit>(
      () => PepiniereCubit(
        getIt<InboxRepository>(),
        getIt<TransplantSeedling>(),
        getIt<VaultWriteNotifier>(),
      ),
    );

  // Sync: fake git backend, real orchestration/presentation.
  getIt
    ..registerLazySingleton<PullChangeNotifier>(
      PullChangeNotifier.new,
      dispose: (notifier) => notifier.dispose(),
    )
    ..registerLazySingleton<VaultWriteNotifier>(
      VaultWriteNotifier.new,
      dispose: (notifier) => notifier.dispose(),
    )
    ..registerLazySingleton<GitSyncRepository>(
      () => fakeGitSyncRepository,
      dispose: (repository) => (repository as FakeGitSyncRepository).dispose(),
    )
    ..registerFactory<ForceSynchronize>(
      () => ForceSynchronize(getIt<GitSyncRepository>()),
    )
    ..registerFactory<GetSyncStatus>(
      () => GetSyncStatus(getIt<GitSyncRepository>()),
    )
    ..registerFactory<WatchSyncStatus>(
      () => WatchSyncStatus(getIt<GitSyncRepository>()),
    )
    ..registerFactory<TestRemoteConnection>(
      () => TestRemoteConnection(getIt<GitSyncRepository>()),
    )
    ..registerFactory<UpdateGitToken>(
      () => UpdateGitToken(getIt<GitSyncRepository>()),
    )
    ..registerFactory<SettingsCubit>(
      () => SettingsCubit(
        getIt<GetVaultConfig>(),
        getIt<GetSyncStatus>(),
        getIt<TestRemoteConnection>(),
        getIt<UpdateGitToken>(),
        getIt<ForceSynchronize>(),
        getIt<GitSyncRepository>(),
      ),
    )
    ..registerFactory<SyncStatusCubit>(
      () => SyncStatusCubit(
        getIt<GetSyncStatus>(),
        getIt<WatchSyncStatus>(),
        getIt<ForceSynchronize>(),
        getIt<NetworkInfo>(),
      ),
    )
    // Registered but NOT started: steps that need the background sync loop
    // call `getIt<SyncOrchestrator>().start()` themselves and pump past its
    // 2 s commit debounce with `tester.pump(const Duration(seconds: 3))`.
    ..registerLazySingleton<SyncOrchestrator>(
      () => SyncOrchestrator(
        getIt<GitSyncRepository>(),
        getIt<ZettelRepository>(),
        getIt<NetworkInfo>(),
        getIt<PullChangeNotifier>(),
        getIt<VaultWriteNotifier>(),
        getIt<Clock>(),
      ),
      dispose: (orchestrator) => orchestrator.dispose(),
    );

  // Setup: real onboarding orchestration over in-memory persistence.
  getIt
    ..registerLazySingleton<SetupLocalDataSource>(
      () => fakeSetupLocalDataSource,
    )
    ..registerLazySingleton<SetupRepository>(
      () => SetupRepositoryImpl(
        getIt<SetupLocalDataSource>(),
        getIt<GitSyncRepository>(),
        getIt<VaultLocator>(),
      ),
    )
    ..registerFactory<ConfigureLocalOnly>(
      () => ConfigureLocalOnly(getIt<SetupRepository>()),
    )
    ..registerFactory<ConfigureWithRemote>(
      () => ConfigureWithRemote(getIt<SetupRepository>()),
    )
    ..registerFactory<GetVaultConfig>(
      () => GetVaultConfig(getIt<SetupRepository>()),
    )
    ..registerFactory<SetupBloc>(
      () =>
          SetupBloc(getIt<ConfigureWithRemote>(), getIt<ConfigureLocalOnly>()),
    );
}
