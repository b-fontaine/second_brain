import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/services/local_ai_service.dart';

/// Catalog of the on-device LLM models supported by the app.
///
/// The default model is Qwen3 0.6B: public HuggingFace repository (no token
/// required), `.litertlm` format so it runs on every supported platform
/// (Android arm64, iOS, macOS Apple Silicon, Windows x64, Linux).
class GemmaModelCatalog {
  const GemmaModelCatalog._();

  /// Qwen3 0.6B — ~586 MB, public repo, thinking + function calling.
  /// Canonical HF URL (must use `/resolve/`, never `/blob/`).
  static const String defaultModelUrl =
      'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/'
      'Qwen3-0.6B.litertlm';

  /// File name used by flutter_gemma as the installed model identifier.
  static const String defaultModelFileName = 'Qwen3-0.6B.litertlm';

  static const ModelType defaultModelType = ModelType.qwen3;

  /// Gemma 3 1B — ~0.5 GB, better French quality, but the HF repo is GATED:
  /// requires a HuggingFace token passed to `FlutterGemma.initialize` and a
  /// one-time "Request access" on the repository page.
  static const String gemma3AlternativeUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/'
      'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';

  static const String gemma3AlternativeFileName =
      'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';

  static const ModelType gemma3AlternativeType = ModelType.gemmaIt;
}

/// [LocalAiService] backed by flutter_gemma (LiteRT-LM engine).
///
/// Requires `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])`
/// to have been awaited in `main()` before any call (see DECISIONS.md).
@LazySingleton(as: LocalAiService)
class GemmaLocalAiService implements LocalAiService {
  GemmaLocalAiService();

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
      if (await FlutterGemma.isModelInstalled(
        GemmaModelCatalog.defaultModelFileName,
      )) {
        return true;
      }
      return FlutterGemma.isModelInstalled(
        GemmaModelCatalog.gemma3AlternativeFileName,
      );
    } catch (error) {
      throw AiException(_describeError(error));
    }
  }

  @override
  Stream<ModelDownloadProgress> installModel() {
    final controller = StreamController<ModelDownloadProgress>();

    Future<void> run() async {
      try {
        // install() is idempotent: an already-installed model skips the
        // download and is simply (re)set as the active inference model.
        await FlutterGemma.installModel(
          modelType: GemmaModelCatalog.defaultModelType,
          fileType: ModelFileType.litertlm,
        ).fromNetwork(GemmaModelCatalog.defaultModelUrl).withProgress((
          int percent,
        ) {
          if (!controller.isClosed) {
            controller.add(
              ModelDownloadProgress((percent / 100).clamp(0.0, 1.0)),
            );
          }
        }).install();
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
    final model = _model;
    _model = null;
    if (model != null) {
      try {
        await model.close();
      } catch (_) {
        // Native teardown failures must not crash app shutdown.
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
