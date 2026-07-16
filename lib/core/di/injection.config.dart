// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:connectivity_plus/connectivity_plus.dart' as _i895;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/assistant/data/datasources/gemma_local_ai_service.dart'
    as _i961;
import '../../features/assistant/data/datasources/rag_embeddings_gateway.dart'
    as _i403;
import '../../features/assistant/data/datasources/vault_rag_index.dart'
    as _i835;
import '../../features/assistant/data/repositories/gemma_assistant_repository.dart'
    as _i834;
import '../../features/assistant/domain/repositories/assistant_repository.dart'
    as _i814;
import '../../features/assistant/domain/services/local_ai_service.dart'
    as _i173;
import '../../features/assistant/presentation/bloc/chat_bloc.dart' as _i509;
import '../../features/assistant/presentation/bloc/dictation_cubit.dart'
    as _i589;
import '../../features/assistant/presentation/bloc/model_status_cubit.dart'
    as _i592;
import '../../features/capture/data/services/app_directories.dart' as _i636;
import '../../features/capture/data/services/composite_ocr_service.dart'
    as _i833;
import '../../features/capture/data/services/file_downloader.dart' as _i842;
import '../../features/capture/data/services/host_platform.dart' as _i974;
import '../../features/capture/data/services/macos_vision_ocr_backend.dart'
    as _i730;
import '../../features/capture/data/services/mlkit_ocr_backend.dart' as _i235;
import '../../features/capture/data/services/process_runner.dart' as _i464;
import '../../features/capture/data/services/sherpa_transcription_service.dart'
    as _i127;
import '../../features/capture/data/services/stt_model_store.dart' as _i119;
import '../../features/capture/data/services/system_clipboard_service.dart'
    as _i635;
import '../../features/capture/data/services/tesseract_cli_ocr_backend.dart'
    as _i839;
import '../../features/capture/domain/services/capture_intake.dart' as _i18;
import '../../features/capture/domain/services/clipboard_service.dart' as _i751;
import '../../features/capture/domain/services/ocr_service.dart' as _i894;
import '../../features/capture/domain/services/transcription_service.dart'
    as _i228;
import '../../features/capture/domain/usecases/accept_draft.dart' as _i772;
import '../../features/capture/domain/usecases/capture_from_clipboard.dart'
    as _i590;
import '../../features/capture/domain/usecases/ensure_stt_model.dart' as _i320;
import '../../features/capture/domain/usecases/process_capture.dart' as _i1068;
import '../../features/capture/domain/usecases/recognize_screenshot.dart'
    as _i848;
import '../../features/capture/domain/usecases/start_dictation.dart' as _i386;
import '../../features/capture/domain/usecases/stop_dictation.dart' as _i1035;
import '../../features/capture/domain/usecases/transcribe_audio_file.dart'
    as _i131;
import '../../features/capture/presentation/bloc/capture_bloc.dart' as _i181;
import '../../features/capture/presentation/bloc/pepiniere_cubit.dart' as _i548;
import '../../features/capture/presentation/bloc/seed_intake_cubit.dart'
    as _i486;
import '../../features/explorer/presentation/bloc/seedling_count_cubit.dart'
    as _i387;
import '../../features/graph/domain/usecases/suggest_related_notes.dart'
    as _i65;
import '../../features/graph/domain/usecases/watch_vault.dart' as _i399;
import '../../features/graph/presentation/bloc/graph_cubit.dart' as _i934;
import '../../features/setup/data/datasources/documents_directory_provider.dart'
    as _i697;
import '../../features/setup/data/datasources/setup_local_data_source.dart'
    as _i96;
import '../../features/setup/data/repositories/setup_repository_impl.dart'
    as _i776;
import '../../features/setup/domain/repositories/setup_repository.dart'
    as _i329;
import '../../features/setup/domain/usecases/configure_local_only.dart' as _i34;
import '../../features/setup/domain/usecases/configure_with_remote.dart'
    as _i828;
import '../../features/setup/domain/usecases/get_vault_config.dart' as _i109;
import '../../features/setup/presentation/bloc/setup_bloc.dart' as _i791;
import '../../features/sync/application/sync_orchestrator.dart' as _i236;
import '../../features/sync/data/datasources/git2dart_client.dart' as _i650;
import '../../features/sync/data/datasources/git_client.dart' as _i83;
import '../../features/sync/data/datasources/secure_storage_module.dart'
    as _i686;
import '../../features/sync/data/repositories/git_sync_repository_impl.dart'
    as _i700;
import '../../features/sync/data/services/pull_change_notifier.dart' as _i727;
import '../../features/sync/domain/repositories/git_sync_repository.dart'
    as _i22;
import '../../features/sync/domain/usecases/force_synchronize.dart' as _i376;
import '../../features/sync/domain/usecases/get_sync_status.dart' as _i397;
import '../../features/sync/domain/usecases/test_remote_connection.dart'
    as _i208;
import '../../features/sync/domain/usecases/update_git_token.dart' as _i719;
import '../../features/sync/domain/usecases/watch_sync_status.dart' as _i207;
import '../../features/sync/presentation/bloc/settings_cubit.dart' as _i775;
import '../../features/sync/presentation/bloc/sync_status_cubit.dart' as _i690;
import '../../features/zettel/data/datasources/vault_data_source.dart' as _i342;
import '../../features/zettel/data/repositories/inbox_repository_impl.dart'
    as _i674;
import '../../features/zettel/data/repositories/zettel_repository_impl.dart'
    as _i891;
import '../../features/zettel/domain/repositories/inbox_repository.dart'
    as _i626;
import '../../features/zettel/domain/repositories/zettel_repository.dart'
    as _i797;
import '../../features/zettel/domain/usecases/create_zettel.dart' as _i499;
import '../../features/zettel/domain/usecases/delete_zettel.dart' as _i879;
import '../../features/zettel/domain/usecases/get_all_zettels.dart' as _i677;
import '../../features/zettel/domain/usecases/get_backlinks.dart' as _i312;
import '../../features/zettel/domain/usecases/get_zettel_by_id.dart' as _i651;
import '../../features/zettel/domain/usecases/search_zettels.dart' as _i93;
import '../../features/zettel/domain/usecases/transplant_seedling.dart'
    as _i309;
import '../../features/zettel/domain/usecases/update_zettel.dart' as _i767;
import '../../features/zettel/presentation/bloc/notes_list/notes_list_bloc.dart'
    as _i678;
import '../../features/zettel/presentation/bloc/zettel_detail/zettel_detail_cubit.dart'
    as _i546;
import '../../features/zettel/presentation/bloc/zettel_edit/zettel_edit_bloc.dart'
    as _i644;
import '../services/clock.dart' as _i239;
import '../services/network_info.dart' as _i1;
import '../services/vault_locator.dart' as _i875;
import '../services/vault_write_notifier.dart' as _i27;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final connectivityModule = _$ConnectivityModule();
    final secureStorageModule = _$SecureStorageModule();
    gh.lazySingleton<_i895.Connectivity>(() => connectivityModule.connectivity);
    gh.lazySingleton<_i27.VaultWriteNotifier>(
      () => _i27.VaultWriteNotifier(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i636.AppDirectories>(() => const _i636.AppDirectories());
    gh.lazySingleton<_i974.HostPlatform>(() => const _i974.HostPlatform());
    gh.lazySingleton<_i730.MacosVisionOcrBackend>(
      () => const _i730.MacosVisionOcrBackend(),
    );
    gh.lazySingleton<_i235.MlKitOcrBackend>(
      () => const _i235.MlKitOcrBackend(),
    );
    gh.lazySingleton<_i464.ProcessRunner>(() => const _i464.ProcessRunner());
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => secureStorageModule.secureStorage,
    );
    gh.lazySingleton<_i727.PullChangeNotifier>(
      () => _i727.PullChangeNotifier(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i751.ClipboardService>(
      () => _i635.SystemClipboardService(
        gh<_i974.HostPlatform>(),
        gh<_i636.AppDirectories>(),
      ),
    );
    gh.lazySingleton<_i697.DocumentsDirectoryProvider>(
      () => _i697.PathProviderDocumentsDirectoryProvider(),
    );
    gh.lazySingleton<_i173.LocalAiService>(() => _i961.GemmaLocalAiService());
    gh.lazySingleton<_i842.FileDownloader>(
      () => const _i842.HttpFileDownloader(),
    );
    gh.lazySingleton<_i119.SttModelStore>(
      () => _i119.SttModelStore(
        gh<_i842.FileDownloader>(),
        gh<_i636.AppDirectories>(),
        gh<_i974.HostPlatform>(),
      ),
    );
    gh.lazySingleton<_i403.RagEmbeddingsGateway>(
      () => _i403.GemmaRagEmbeddingsGateway(),
    );
    gh.lazySingleton<_i239.Clock>(() => _i239.SystemClock());
    gh.lazySingleton<_i875.VaultLocator>(() => _i875.PreferencesVaultLocator());
    gh.lazySingleton<_i839.TesseractCliOcrBackend>(
      () => _i839.TesseractCliOcrBackend(
        gh<_i464.ProcessRunner>(),
        gh<_i974.HostPlatform>(),
      ),
    );
    gh.lazySingleton<_i228.TranscriptionService>(
      () => _i127.SherpaTranscriptionService(
        gh<_i119.SttModelStore>(),
        gh<_i974.HostPlatform>(),
      ),
    );
    gh.lazySingleton<_i96.SetupLocalDataSource>(
      () => _i96.SetupLocalDataSourceImpl(
        gh<_i558.FlutterSecureStorage>(),
        gh<_i697.DocumentsDirectoryProvider>(),
        gh<_i239.Clock>(),
      ),
    );
    gh.lazySingleton<_i894.OcrService>(
      () => _i833.CompositeOcrService(
        gh<_i974.HostPlatform>(),
        gh<_i235.MlKitOcrBackend>(),
        gh<_i730.MacosVisionOcrBackend>(),
        gh<_i839.TesseractCliOcrBackend>(),
      ),
    );
    gh.lazySingleton<_i1.NetworkInfo>(
      () => _i1.ConnectivityNetworkInfo(gh<_i895.Connectivity>()),
    );
    gh.factory<_i590.CaptureFromClipboard>(
      () => _i590.CaptureFromClipboard(gh<_i751.ClipboardService>()),
    );
    gh.lazySingleton<_i342.VaultDataSource>(
      () => _i342.FileVaultDataSource(gh<_i875.VaultLocator>()),
    );
    gh.lazySingleton<_i797.ZettelRepository>(
      () => _i891.ZettelRepositoryImpl(
        gh<_i342.VaultDataSource>(),
        gh<_i239.Clock>(),
      ),
      dispose: _i891.disposeZettelRepository,
    );
    gh.lazySingleton<_i83.GitClient>(
      () => _i650.Git2dartClient(gh<_i239.Clock>()),
    );
    gh.factory<_i589.DictationCubit>(
      () => _i589.DictationCubit(gh<_i228.TranscriptionService>()),
    );
    gh.factory<_i848.RecognizeScreenshot>(
      () => _i848.RecognizeScreenshot(gh<_i894.OcrService>()),
    );
    gh.factory<_i320.EnsureSttModel>(
      () => _i320.EnsureSttModel(gh<_i228.TranscriptionService>()),
    );
    gh.factory<_i386.StartDictation>(
      () => _i386.StartDictation(gh<_i228.TranscriptionService>()),
    );
    gh.factory<_i1035.StopDictation>(
      () => _i1035.StopDictation(gh<_i228.TranscriptionService>()),
    );
    gh.factory<_i131.TranscribeAudioFile>(
      () => _i131.TranscribeAudioFile(gh<_i228.TranscriptionService>()),
    );
    gh.lazySingleton<_i835.VaultRagIndex>(
      () => _i835.VaultRagIndex(
        gh<_i797.ZettelRepository>(),
        gh<_i403.RagEmbeddingsGateway>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.factory<_i399.WatchVault>(
      () => _i399.WatchVault(gh<_i797.ZettelRepository>()),
    );
    gh.factory<_i499.CreateZettel>(
      () => _i499.CreateZettel(gh<_i797.ZettelRepository>()),
    );
    gh.factory<_i879.DeleteZettel>(
      () => _i879.DeleteZettel(gh<_i797.ZettelRepository>()),
    );
    gh.factory<_i677.GetAllZettels>(
      () => _i677.GetAllZettels(gh<_i797.ZettelRepository>()),
    );
    gh.factory<_i312.GetBacklinks>(
      () => _i312.GetBacklinks(gh<_i797.ZettelRepository>()),
    );
    gh.factory<_i651.GetZettelById>(
      () => _i651.GetZettelById(gh<_i797.ZettelRepository>()),
    );
    gh.factory<_i93.SearchZettels>(
      () => _i93.SearchZettels(gh<_i797.ZettelRepository>()),
    );
    gh.factory<_i767.UpdateZettel>(
      () => _i767.UpdateZettel(gh<_i797.ZettelRepository>()),
    );
    gh.lazySingleton<_i814.AssistantRepository>(
      () => _i834.GemmaAssistantRepository(
        gh<_i173.LocalAiService>(),
        gh<_i835.VaultRagIndex>(),
        gh<_i797.ZettelRepository>(),
      ),
    );
    gh.lazySingleton<_i626.InboxRepository>(
      () => _i674.InboxRepositoryImpl(
        gh<_i342.VaultDataSource>(),
        gh<_i27.VaultWriteNotifier>(),
      ),
    );
    gh.factory<_i387.SeedlingCountCubit>(
      () => _i387.SeedlingCountCubit(
        gh<_i626.InboxRepository>(),
        gh<_i27.VaultWriteNotifier>(),
      ),
    );
    gh.lazySingleton<_i22.GitSyncRepository>(
      () => _i700.GitSyncRepositoryImpl(
        gh<_i83.GitClient>(),
        gh<_i875.VaultLocator>(),
        gh<_i1.NetworkInfo>(),
        gh<_i558.FlutterSecureStorage>(),
        gh<_i239.Clock>(),
        gh<_i727.PullChangeNotifier>(),
      ),
      dispose: _i700.disposeGitSyncRepository,
    );
    gh.factory<_i65.SuggestRelatedNotes>(
      () => _i65.SuggestRelatedNotes(
        gh<_i797.ZettelRepository>(),
        gh<_i835.VaultRagIndex>(),
      ),
    );
    gh.factory<_i772.AcceptDraft>(
      () => _i772.AcceptDraft(
        gh<_i499.CreateZettel>(),
        gh<_i626.InboxRepository>(),
      ),
    );
    gh.factory<_i309.TransplantSeedling>(
      () => _i309.TransplantSeedling(
        gh<_i499.CreateZettel>(),
        gh<_i626.InboxRepository>(),
      ),
    );
    gh.factory<_i1068.ProcessCapture>(
      () => _i1068.ProcessCapture(
        gh<_i626.InboxRepository>(),
        gh<_i814.AssistantRepository>(),
        gh<_i239.Clock>(),
      ),
    );
    gh.factory<_i376.ForceSynchronize>(
      () => _i376.ForceSynchronize(gh<_i22.GitSyncRepository>()),
    );
    gh.factory<_i397.GetSyncStatus>(
      () => _i397.GetSyncStatus(gh<_i22.GitSyncRepository>()),
    );
    gh.factory<_i208.TestRemoteConnection>(
      () => _i208.TestRemoteConnection(gh<_i22.GitSyncRepository>()),
    );
    gh.factory<_i719.UpdateGitToken>(
      () => _i719.UpdateGitToken(gh<_i22.GitSyncRepository>()),
    );
    gh.factory<_i207.WatchSyncStatus>(
      () => _i207.WatchSyncStatus(gh<_i22.GitSyncRepository>()),
    );
    gh.factory<_i509.ChatBloc>(
      () => _i509.ChatBloc(gh<_i814.AssistantRepository>()),
    );
    gh.factory<_i592.ModelStatusCubit>(
      () => _i592.ModelStatusCubit(gh<_i814.AssistantRepository>()),
    );
    gh.factory<_i934.GraphCubit>(
      () => _i934.GraphCubit(
        gh<_i677.GetAllZettels>(),
        gh<_i399.WatchVault>(),
        gh<_i65.SuggestRelatedNotes>(),
      ),
    );
    gh.factory<_i548.PepiniereCubit>(
      () => _i548.PepiniereCubit(
        gh<_i626.InboxRepository>(),
        gh<_i309.TransplantSeedling>(),
        gh<_i27.VaultWriteNotifier>(),
      ),
    );
    gh.factory<_i678.NotesListBloc>(
      () => _i678.NotesListBloc(
        gh<_i677.GetAllZettels>(),
        gh<_i93.SearchZettels>(),
        gh<_i797.ZettelRepository>(),
      ),
    );
    gh.lazySingleton<_i18.CaptureIntake>(
      () => _i18.CaptureIntake(
        gh<_i848.RecognizeScreenshot>(),
        gh<_i131.TranscribeAudioFile>(),
        gh<_i173.LocalAiService>(),
        gh<_i626.InboxRepository>(),
        gh<_i239.Clock>(),
      ),
    );
    gh.factory<_i546.ZettelDetailCubit>(
      () => _i546.ZettelDetailCubit(
        gh<_i651.GetZettelById>(),
        gh<_i312.GetBacklinks>(),
        gh<_i879.DeleteZettel>(),
      ),
    );
    gh.factory<_i644.ZettelEditBloc>(
      () => _i644.ZettelEditBloc(
        gh<_i499.CreateZettel>(),
        gh<_i767.UpdateZettel>(),
        gh<_i651.GetZettelById>(),
        gh<_i309.TransplantSeedling>(),
      ),
    );
    gh.lazySingleton<_i236.SyncOrchestrator>(
      () => _i236.SyncOrchestrator(
        gh<_i22.GitSyncRepository>(),
        gh<_i797.ZettelRepository>(),
        gh<_i1.NetworkInfo>(),
        gh<_i727.PullChangeNotifier>(),
        gh<_i27.VaultWriteNotifier>(),
        gh<_i239.Clock>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.factory<_i690.SyncStatusCubit>(
      () => _i690.SyncStatusCubit(
        gh<_i397.GetSyncStatus>(),
        gh<_i207.WatchSyncStatus>(),
        gh<_i376.ForceSynchronize>(),
        gh<_i1.NetworkInfo>(),
      ),
    );
    gh.lazySingleton<_i329.SetupRepository>(
      () => _i776.SetupRepositoryImpl(
        gh<_i96.SetupLocalDataSource>(),
        gh<_i22.GitSyncRepository>(),
        gh<_i875.VaultLocator>(),
      ),
    );
    gh.factory<_i181.CaptureBloc>(
      () => _i181.CaptureBloc(
        captureFromClipboard: gh<_i590.CaptureFromClipboard>(),
        transcribeAudioFile: gh<_i131.TranscribeAudioFile>(),
        recognizeScreenshot: gh<_i848.RecognizeScreenshot>(),
        processCapture: gh<_i1068.ProcessCapture>(),
        acceptDraft: gh<_i772.AcceptDraft>(),
        startDictation: gh<_i386.StartDictation>(),
        stopDictation: gh<_i1035.StopDictation>(),
        ensureSttModel: gh<_i320.EnsureSttModel>(),
        captureIntake: gh<_i18.CaptureIntake>(),
      ),
    );
    gh.factory<_i486.SeedIntakeCubit>(
      () => _i486.SeedIntakeCubit(
        gh<_i18.CaptureIntake>(),
        gh<_i590.CaptureFromClipboard>(),
        gh<_i320.EnsureSttModel>(),
      ),
    );
    gh.factory<_i34.ConfigureLocalOnly>(
      () => _i34.ConfigureLocalOnly(gh<_i329.SetupRepository>()),
    );
    gh.factory<_i828.ConfigureWithRemote>(
      () => _i828.ConfigureWithRemote(gh<_i329.SetupRepository>()),
    );
    gh.factory<_i109.GetVaultConfig>(
      () => _i109.GetVaultConfig(gh<_i329.SetupRepository>()),
    );
    gh.factory<_i791.SetupBloc>(
      () => _i791.SetupBloc(
        gh<_i828.ConfigureWithRemote>(),
        gh<_i34.ConfigureLocalOnly>(),
      ),
    );
    gh.factory<_i775.SettingsCubit>(
      () => _i775.SettingsCubit(
        gh<_i109.GetVaultConfig>(),
        gh<_i397.GetSyncStatus>(),
        gh<_i208.TestRemoteConnection>(),
        gh<_i719.UpdateGitToken>(),
        gh<_i376.ForceSynchronize>(),
        gh<_i22.GitSyncRepository>(),
      ),
    );
    return this;
  }
}

class _$ConnectivityModule extends _i1.ConnectivityModule {}

class _$SecureStorageModule extends _i686.SecureStorageModule {}
