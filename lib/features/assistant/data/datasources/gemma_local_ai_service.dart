import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/ai_model_option.dart';
import '../../domain/repositories/ai_model_preferences.dart';
import '../../domain/services/local_ai_service.dart';

/// Everything [GemmaLocalAiService] needs to install one on-device model.
class GemmaModelCatalogEntry {
  const GemmaModelCatalogEntry({
    required this.url,
    required this.fileName,
    required this.modelType,
  });

  /// Canonical HF URL (must use `/resolve/`, never `/blob/`).
  final String url;

  /// File name used by flutter_gemma as the installed model identifier.
  final String fileName;

  final ModelType modelType;
}

/// Catalog of the on-device LLM models supported by the app, keyed by the
/// domain-level [AiModelId] so the rest of the app never has to know about
/// flutter_gemma types or HuggingFace URLs.
///
/// All three models are public HuggingFace repositories (no token
/// required), `.litertlm` format so they run on every supported platform
/// (Android arm64, iOS, macOS Apple Silicon, Windows x64, Linux).
abstract final class GemmaModelCatalog {
  const GemmaModelCatalog._();

  /// Qwen3 0.6B — ~586 MB, thinking + function calling, text only. Default:
  /// smallest download, runs comfortably on every supported device.
  static const qwen3 = GemmaModelCatalogEntry(
    url:
        'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/'
        'Qwen3-0.6B.litertlm',
    fileName: 'Qwen3-0.6B.litertlm',
    modelType: ModelType.qwen3,
  );

  /// Gemma 4 E2B — ~2.6 GB, multimodal (text/image/audio), function
  /// calling + thinking mode, better French quality. Public repo.
  static const gemma4E2B = GemmaModelCatalogEntry(
    url:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/'
        'resolve/main/gemma-4-E2B-it.litertlm',
    fileName: 'gemma-4-E2B-it.litertlm',
    modelType: ModelType.gemma4,
  );

  /// Gemma 4 E4B — ~3.7 GB, same capabilities as E2B, larger and slower.
  static const gemma4E4B = GemmaModelCatalogEntry(
    url:
        'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/'
        'resolve/main/gemma-4-E4B-it.litertlm',
    fileName: 'gemma-4-E4B-it.litertlm',
    modelType: ModelType.gemma4,
  );

  static const Map<AiModelId, GemmaModelCatalogEntry> byId = {
    AiModelId.qwen3: qwen3,
    AiModelId.gemma4E2B: gemma4E2B,
    AiModelId.gemma4E4B: gemma4E4B,
  };

  /// The model to use absent an explicit user choice (first run).
  static const AiModelId defaultModelId = AiModelId.qwen3;

  static GemmaModelCatalogEntry entryFor(AiModelId id) => byId[id]!;
}

/// [LocalAiService] backed by flutter_gemma (LiteRT-LM engine).
///
/// Requires `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])`
/// to have been awaited in `main()` before any call (see DECISIONS.md).
@LazySingleton(as: LocalAiService)
class GemmaLocalAiService implements LocalAiService {
  GemmaLocalAiService(this._preferences);

  final AiModelPreferences _preferences;

  /// Context window (input + output). `.litertlm` models require >= 1024.
  static const int _contextWindowTokens = 2048;

  /// Cap on generated tokens per response (honored on the .litertlm path).
  static const int _maxOutputTokens = 1024;

  static const double _temperature = 0.7;

  static const String _unsupportedArchitectureMessage =
      "L'IA locale n'est pas disponible sur cette machine : les Mac Intel "
      'et les PC Windows ARM ne sont pas pris en charge par le moteur '
      "d'inférence. L'application reste utilisable sans assistant.";

  /// Loaded model instance, created lazily on first generation and reused
  /// across calls. Sessions, in contrast, are created per call.
  InferenceModel? _model;

  @override
  Future<bool> isModelReady() async {
    try {
      final entry = await _selectedEntry();
      return await FlutterGemma.isModelInstalled(entry.fileName);
    } catch (error) {
      throw AiException(_describeError(error));
    }
  }

  @override
  Stream<ModelDownloadProgress> installModel() {
    final controller = StreamController<ModelDownloadProgress>();

    Future<void> run() async {
      try {
        final entry = await _selectedEntry();
        // install() is idempotent: an already-installed model skips the
        // download and is simply (re)set as the active inference model.
        await FlutterGemma.installModel(
          modelType: entry.modelType,
          fileType: ModelFileType.litertlm,
        ).fromNetwork(entry.url).withProgress((
          int percent,
        ) {
          if (!controller.isClosed) {
            controller.add(
              ModelDownloadProgress((percent / 100).clamp(0.0, 1.0)),
            );
          }
        }).install();
        // The just-installed model becomes the SDK's active model, but the
        // cached `_model` (if any) still points at whichever model was
        // active before — invalidate it so the next generation re-resolves
        // to the newly installed one instead of silently reusing the old.
        await _invalidateActiveModel();
        if (!controller.isClosed) {
          controller.add(const ModelDownloadProgress(1.0));
        }
      } on DownloadException catch (exception) {
        controller.addError(
          AiException(_describeDownloadError(exception.error)),
        );
      } catch (error) {
        controller.addError(AiException(_describeError(error)));
      } finally {
        await controller.close();
      }
    }

    controller.onListen = () {
      unawaited(run());
    };
    return controller.stream;
  }

  @override
  Future<String> generate(String prompt, {String? systemPrompt}) async {
    final (session, systemPromptApplied) = await _openSession(systemPrompt);
    try {
      final text = systemPromptApplied
          ? prompt
          : _prefixSystemPrompt(prompt, systemPrompt);
      await session.addQueryChunk(Message.text(text: text, isUser: true));
      return await session.getResponse();
    } on AiException {
      rethrow;
    } catch (error) {
      throw AiException(_describeError(error));
    } finally {
      await _closeQuietly(session);
    }
  }

  @override
  Stream<String> generateStream(String prompt, {String? systemPrompt}) async* {
    final (session, systemPromptApplied) = await _openSession(systemPrompt);
    try {
      final text = systemPromptApplied
          ? prompt
          : _prefixSystemPrompt(prompt, systemPrompt);
      await session.addQueryChunk(Message.text(text: text, isUser: true));
      await for (final token in session.getResponseAsync()) {
        yield token;
      }
    } on AiException {
      rethrow;
    } catch (error) {
      throw AiException(_describeError(error));
    } finally {
      await _closeQuietly(session);
    }
  }

  @override
  Future<void> dispose() async {
    await _invalidateActiveModel();
  }

  /// Closes and drops the cached [_model] so the next [_obtainModel] call
  /// re-fetches the SDK's current active model instead of reusing a stale
  /// reference (used on shutdown and after installing a different model).
  Future<void> _invalidateActiveModel() async {
    final model = _model;
    _model = null;
    if (model != null) {
      try {
        await model.close();
      } catch (_) {
        // Native teardown failures must not crash app shutdown/switching.
      }
    }
  }

  /// Creates a fresh session for a single generation call.
  ///
  /// Tries the native `systemInstruction` first; when the active engine does
  /// not support it, falls back to a plain session and reports `false` so the
  /// caller prefixes the system prompt into the user message instead.
  Future<(InferenceModelSession, bool)> _openSession(
    String? systemPrompt,
  ) async {
    final model = await _obtainModel();
    if (systemPrompt == null || systemPrompt.trim().isEmpty) {
      final session = await _createSession(model, systemInstruction: null);
      return (session, true);
    }
    try {
      final session = await _createSession(
        model,
        systemInstruction: systemPrompt,
      );
      return (session, true);
    } on UnsupportedError {
      final session = await _createSession(model, systemInstruction: null);
      return (session, false);
    } on ArgumentError {
      final session = await _createSession(model, systemInstruction: null);
      return (session, false);
    }
  }

  Future<InferenceModelSession> _createSession(
    InferenceModel model, {
    required String? systemInstruction,
  }) {
    return model.createSession(
      temperature: _temperature,
      systemInstruction: systemInstruction,
      maxOutputTokens: _maxOutputTokens,
    );
  }

  Future<InferenceModel> _obtainModel() async {
    final existing = _model;
    if (existing != null) return existing;
    try {
      final model = await FlutterGemma.getActiveModel(
        maxTokens: _contextWindowTokens,
        preferredBackend: PreferredBackend.gpu,
      );
      _model = model;
      return model;
    } on StateError catch (error) {
      throw AiException(
        "Aucun modèle IA n'est installé. Téléchargez le modèle depuis "
        "l'écran de configuration avant d'utiliser l'assistant. "
        '(${error.message})',
      );
    } catch (error) {
      throw AiException(_describeError(error));
    }
  }

  /// The catalog entry for the user's chosen model, or the default
  /// ([GemmaModelCatalog.defaultModelId]) when none was chosen yet.
  Future<GemmaModelCatalogEntry> _selectedEntry() async {
    final selected = await _preferences.getSelectedModel();
    return GemmaModelCatalog.entryFor(
      selected ?? GemmaModelCatalog.defaultModelId,
    );
  }

  String _prefixSystemPrompt(String prompt, String? systemPrompt) {
    if (systemPrompt == null || systemPrompt.trim().isEmpty) return prompt;
    return '$systemPrompt\n\n$prompt';
  }

  Future<void> _closeQuietly(InferenceModelSession session) async {
    try {
      await session.close();
    } catch (_) {
      // A session close failure must not mask the generation result/error.
    }
  }

  /// User-facing French message for model download failures.
  String _describeDownloadError(DownloadError error) {
    return switch (error) {
      UnauthorizedError() =>
        'Authentification requise (HTTP 401) : ce modèle nécessite un jeton '
            'Hugging Face valide.',
      ForbiddenError() =>
        'Accès refusé (HTTP 403) : ce modèle est à accès restreint. Demandez '
            "l'accès sur sa page Hugging Face puis fournissez un jeton valide.",
      NotFoundError() =>
        "Modèle introuvable (HTTP 404) : l'adresse de téléchargement du "
            'modèle est invalide.',
      RateLimitedError() =>
        'Trop de requêtes vers le serveur de téléchargement (HTTP 429). '
            'Réessayez dans quelques minutes.',
      ServerError(:final statusCode) =>
        'Le serveur de téléchargement a renvoyé une erreur '
            '(HTTP $statusCode). Réessayez plus tard.',
      NetworkError() =>
        'Erreur réseau pendant le téléchargement du modèle. Vérifiez votre '
            'connexion internet puis réessayez.',
      CanceledError() => 'Téléchargement du modèle annulé.',
      UnknownError(:final message) =>
        'Échec du téléchargement du modèle : $message',
    };
  }

  /// User-facing French message for engine/inference failures, with a
  /// dedicated message for the unsupported-architecture case
  /// (macOS Intel / Windows arm64 — see DECISIONS.md).
  String _describeError(Object error) {
    final text = error.toString();
    final looksLikeUnsupportedArchitecture =
        error is UnsupportedError ||
        text.contains('not supported for FFI') ||
        text.contains('Failed to preload') ||
        text.contains('Failed to load libLiteRtLm') ||
        text.contains('dlopen');
    if (looksLikeUnsupportedArchitecture) {
      return _unsupportedArchitectureMessage;
    }
    return 'Erreur du moteur IA local : $text';
  }
}
