import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../../core/error/exceptions.dart';
import '../../domain/services/transcription_service.dart';
import '../../domain/usecases/start_dictation.dart'
    show MicrophonePermissionDeniedException;
import 'host_platform.dart';
import 'pcm_convert.dart';
import 'stt_model_store.dart';

/// Offline STT backed by sherpa-onnx.
///
/// - Live dictation: streaming zipformer FR transducer fed by a `record`
///   PCM16 16 kHz mono microphone stream ([sherpa.OnlineRecognizer]).
/// - File transcription: whisper int8 ([sherpa.OfflineRecognizer]) run in a
///   background isolate; WAV PCM 16-bit input only (see transcribeFile).
///
/// Models are downloaded on first use into
/// `getApplicationSupportDirectory()/stt` by [SttModelStore].
@LazySingleton(as: TranscriptionService)
class SherpaTranscriptionService implements TranscriptionService {
  SherpaTranscriptionService(this._models, this._platform);

  final SttModelStore _models;
  final HostPlatform _platform;

  static bool _bindingsInitialized = false;

  // Live dictation session state.
  sherpa.OnlineRecognizer? _onlineRecognizer;
  sherpa.OnlineStream? _onlineStream;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _pcmSubscription;
  StreamController<DictationSegment>? _segments;
  String _lastPartial = '';

  /// Generation token: incremented by every start and stop. An in-flight
  /// [_beginDictation] re-checks it after each await and aborts (releasing
  /// its own resources) when a newer start/stop superseded it, so a stop
  /// racing a slow start can never leave the microphone running.
  int _session = 0;

  static void _ensureBindings() {
    if (!_bindingsInitialized) {
      sherpa.initBindings();
      _bindingsInitialized = true;
    }
  }

  @override
  Future<bool> isReady() => _models.isInstalled();

  @override
  Stream<double> installModel() => _models.install();

  @override
  Future<String> transcribeFile(String path) async {
    if (!await _models.isInstalled()) {
      throw const TranscriptionException(
        "Le modèle de transcription n'est pas installé",
      );
    }
    final file = File(path);
    if (!file.existsSync()) {
      throw TranscriptionException('Fichier audio introuvable : $path');
    }
    final extension = p.extension(path).toLowerCase();
    if (extension != '.wav') {
      // sherpa-onnx readWave only decodes 16-bit PCM WAV. Converting
      // m4a/mp3 would require an external decoder (see integration notes).
      throw TranscriptionException(
        'Format audio non pris en charge ($extension). Seuls les fichiers '
        'WAV (PCM 16 bits) sont acceptés pour le moment. Convertissez le '
        'fichier, par exemple : ffmpeg -i entree$extension -ar 16000 -ac 1 '
        'sortie.wav',
      );
    }
    final modelPaths = await _models.whisperPaths();
    try {
      // Whisper inference is synchronous FFI work: run it off the UI isolate.
      return await Isolate.run(() => _transcribeWavSync(modelPaths, path));
    } on TranscriptionException {
      rethrow;
    } catch (e) {
      throw TranscriptionException('Échec de la transcription : $e');
    }
  }

  /// Runs in a background isolate: bindings must be (re-)initialized there.
  static String _transcribeWavSync(WhisperModelPaths model, String wavPath) {
    sherpa.initBindings();
    final recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: model.encoder,
            decoder: model.decoder,
            language: 'fr',
            task: 'transcribe',
          ),
          tokens: model.tokens,
          modelType: 'whisper',
          numThreads: 2,
          debug: false,
        ),
      ),
    );
    try {
      final wave = sherpa.readWave(wavPath);
      if (wave.samples.isEmpty) {
        throw const TranscriptionException(
          'Le fichier WAV est vide ou illisible',
        );
      }
      // Whisper processes at most ~30 s per pass: split long recordings into
      // fixed windows (no VAD model shipped; acceptable for voice notes).
      final chunkSamples = wave.sampleRate * 28;
      final pieces = <String>[];
      var offset = 0;
      while (offset < wave.samples.length) {
        final end = math.min(offset + chunkSamples, wave.samples.length);
        final chunk = wave.samples.sublist(offset, end);
        final stream = recognizer.createStream();
        try {
          stream.acceptWaveform(samples: chunk, sampleRate: wave.sampleRate);
          recognizer.decode(stream);
          final text = recognizer.getResult(stream).text.trim();
          if (text.isNotEmpty) pieces.add(text);
        } finally {
          stream.free();
        }
        offset = end;
      }
      return pieces.join(' ').trim();
    } on TranscriptionException {
      rethrow;
    } catch (e) {
      throw TranscriptionException('Lecture du fichier WAV impossible : $e');
    } finally {
      recognizer.free();
    }
  }

  @override
  Stream<DictationSegment> startDictation() {
    final controller = StreamController<DictationSegment>();
    controller.onListen = () {
      unawaited(_beginDictation(controller));
    };
    return controller.stream;
  }

  Future<void> _beginDictation(
    StreamController<DictationSegment> controller,
  ) async {
    // Close any previous session cleanly first: the previous controller is
    // closed (its listener gets onDone) and the previous native stream is
    // freed, so a re-entrant start never leaks them.
    await stopDictation();
    final session = ++_session;
    _segments = controller;
    AudioRecorder? recorder;
    try {
      if (!await _models.isInstalled()) {
        throw const TranscriptionException(
          "Le modèle de dictée n'est pas installé",
        );
      }
      if (session != _session) {
        await _abandonStart(recorder, controller);
        return;
      }
      recorder = AudioRecorder();
      _recorder = recorder;
      await _ensureMicPermission(recorder);
      if (session != _session) {
        // Stopped (or restarted) while the permission prompt was pending:
        // the teardown may have run before this recorder existed for it.
        await _abandonStart(recorder, controller);
        return;
      }

      _ensureBindings();
      final paths = await _models.dictationPaths();
      if (session != _session) {
        await _abandonStart(recorder, controller);
        return;
      }
      _onlineRecognizer ??= sherpa.OnlineRecognizer(
        sherpa.OnlineRecognizerConfig(
          model: sherpa.OnlineModelConfig(
            transducer: sherpa.OnlineTransducerModelConfig(
              encoder: paths.encoder,
              decoder: paths.decoder,
              joiner: paths.joiner,
            ),
            tokens: paths.tokens,
            numThreads: 2,
            debug: false,
          ),
          ruleFsts: '',
          enableEndpoint: true,
          rule1MinTrailingSilence: 2.4,
          rule2MinTrailingSilence: 1.2,
          rule3MinUtteranceLength: 20,
          decodingMethod: 'greedy_search',
          maxActivePaths: 4,
        ),
      );
      _onlineStream = _onlineRecognizer!.createStream();
      _lastPartial = '';

      final pcm = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      if (session != _session) {
        // Stopped while the microphone was starting: the earlier teardown
        // could not stop a recorder that was not capturing yet — do it now.
        await _abandonStart(recorder, controller);
        return;
      }
      _pcmSubscription = pcm.listen(
        _onPcmChunk,
        onError: (Object error, StackTrace _) {
          if (!controller.isClosed) {
            controller.addError(
              TranscriptionException('Erreur du microphone : $error'),
            );
          }
        },
      );
    } on TranscriptionException catch (e) {
      await _abortStart(session, recorder, controller, e);
    } catch (e) {
      await _abortStart(
        session,
        recorder,
        controller,
        TranscriptionException('Démarrage de la dictée impossible : $e'),
      );
    }
  }

  /// Cleans up a [_beginDictation] attempt superseded by a newer start/stop:
  /// its recorder is disposed and its stream is ended (a stop already closed
  /// the controller when it owned it — this is a safety net for restarts).
  Future<void> _abandonStart(
    AudioRecorder? recorder,
    StreamController<DictationSegment> controller,
  ) async {
    await _disposeRecorder(recorder);
    if (!controller.isClosed) await controller.close();
  }

  /// Cleans up a failed [_beginDictation] attempt and reports [error] to the
  /// session's listener. Only touches the shared session state when this
  /// attempt still owns it (no newer start/stop happened in between).
  Future<void> _abortStart(
    int session,
    AudioRecorder? recorder,
    StreamController<DictationSegment> controller,
    TranscriptionException error,
  ) async {
    if (session == _session) {
      await _teardownRecording();
      _releaseOnlineStream();
      if (identical(_segments, controller)) _segments = null;
    } else {
      // A newer session owns the shared state; only make sure this
      // attempt's own recorder is stopped.
      await _disposeRecorder(recorder);
    }
    if (!controller.isClosed) {
      controller.addError(error);
      await controller.close();
    }
  }

  /// Frees the native online stream, if any (idempotent, never throws).
  void _releaseOnlineStream() {
    final stream = _onlineStream;
    _onlineStream = null;
    _lastPartial = '';
    if (stream != null) {
      try {
        stream.free();
      } catch (_) {}
    }
  }

  Future<void> _ensureMicPermission(AudioRecorder recorder) async {
    if (_platform.isMobile) {
      final status = await Permission.microphone.request();
      if (!status.isGranted && !status.isLimited) {
        throw const MicrophonePermissionDeniedException();
      }
      return;
    }
    // Desktop: permission_handler does not cover every platform; `record`
    // triggers the macOS prompt itself, Windows/Linux are governed by OS
    // settings without a runtime prompt.
    try {
      if (!await recorder.hasPermission()) {
        throw const MicrophonePermissionDeniedException();
      }
    } on MicrophonePermissionDeniedException {
      rethrow;
    } on Exception {
      // Backend without a permission concept: proceed and let the actual
      // capture fail with a clear error if the mic is unavailable.
    }
  }

  void _onPcmChunk(Uint8List bytes) {
    final stream = _onlineStream;
    final recognizer = _onlineRecognizer;
    final controller = _segments;
    if (stream == null ||
        recognizer == null ||
        controller == null ||
        controller.isClosed) {
      return;
    }
    final samples = pcm16BytesToFloat32(bytes);
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    final text = recognizer.getResult(stream).text.trim();
    if (recognizer.isEndpoint(stream)) {
      if (text.isNotEmpty) {
        controller.add(DictationSegment(text, isFinal: true));
      }
      _lastPartial = '';
      recognizer.reset(stream);
    } else if (text.isNotEmpty && text != _lastPartial) {
      _lastPartial = text;
      controller.add(DictationSegment(text, isFinal: false));
    }
  }

  @override
  Future<void> stopDictation() async {
    _session++; // Invalidate any in-flight _beginDictation.
    final controller = _segments;
    _segments = null;
    await _teardownRecording();

    final stream = _onlineStream;
    final recognizer = _onlineRecognizer;
    if (stream != null && recognizer != null) {
      try {
        while (recognizer.isReady(stream)) {
          recognizer.decode(stream);
        }
        final text = recognizer.getResult(stream).text.trim();
        if (text.isNotEmpty && controller != null && !controller.isClosed) {
          controller.add(DictationSegment(text, isFinal: true));
        }
      } catch (_) {
        // Finalization is best-effort: the partials already reached the UI.
      }
    }
    _releaseOnlineStream();

    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  Future<void> _teardownRecording() async {
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    final recorder = _recorder;
    _recorder = null;
    await _disposeRecorder(recorder);
  }

  /// Stops and disposes [recorder] (idempotent, never throws).
  Future<void> _disposeRecorder(AudioRecorder? recorder) async {
    if (recorder == null) return;
    try {
      await recorder.stop();
    } catch (_) {}
    try {
      await recorder.dispose();
    } catch (_) {}
  }
}
