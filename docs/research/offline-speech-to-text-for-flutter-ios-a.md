# Offline speech-to-text for Flutter (iOS, Android, Windows, Linux, macOS) — live dictation + audio file transcription, French language

## Recommandation

Primary stack: sherpa_onnx ^1.13.4 (k2-fsa, pub.dev, published ~1 week ago) for ALL inference — streaming Zipformer-transducer for live French dictation + Whisper-ONNX (multilingual) for file transcription — combined with record ^7.1.1 for microphone PCM streaming and file recording, and permission_handler ^12.0.3 for runtime mic permission on mobile. This is the only actively-maintained fully-offline stack covering all 5 target platforms for BOTH use cases with true low-latency streaming. Rejected: speech_to_text 7.4.0 (no Linux, uses OS recognition which can be online, cannot transcribe files); whisper_flutter_new 1.0.1 (2 years stale, Android/iOS/macOS only).

## Support plateformes

{"android": true, "ios": true, "windows": true, "linux": true, "macos": true}

## Fallback

Simpler alternative / fallback: whisper_ggml ^2.4.0 (pub.dev, verified publisher antonkarpenko.com, repo github.com/sk3llo/whisper_ggml, MIT, published 2 days ago, whisper.cpp v1.9.1). Also covers all 5 platforms (Android API 21+, iOS 15.6+, macOS 10.15+, Windows 10 x64, Linux x64), auto-downloads models on first use, supports French via lang: 'fr'. API: `final controller = WhisperController(); final result = await controller.transcribe(model: WhisperModel.small, audioPath: '/path/audio.wav', lang: 'fr'); print(result?.transcription.text);` and chunked pseudo-live: `final session = await controller.transcribeLive(model: WhisperModel.base, pcm16Stream: pcmStream, lang: 'fr'); session.partials.listen(...); final text = await session.stop();` (pcmStream from record's startStream at 16kHz mono pcm16bits). Use it if sherpa_onnx model plumbing is too heavy — but its "live" mode is chunked Whisper (seconds of latency), not true streaming, and it is single-maintainer. WhisperModel enum: tiny/base/small/medium/large (multilingual) + tinyEn/baseEn/smallEn/mediumEn. Do NOT use English-only variants for French.

## Entrées pubspec

- `sherpa_onnx: ^1.13.4`
- `record: ^7.1.1`
- `permission_handler: ^12.0.3`
- `path_provider: ^2.1.5`
- `path: ^1.9.0`
- `# fallback alternative: whisper_ggml: ^2.4.0`

## Setup plateforme

ANDROID: AndroidManifest.xml -> <uses-permission android:name="android.permission.RECORD_AUDIO" /> (add android.permission.INTERNET if downloading models at runtime). minSdkVersion 23 (required by record). Request at runtime: `await Permission.microphone.request()` (permission_handler) or rely on `recorder.hasPermission()`. If bundling >100MB models in assets, expect large APK — prefer runtime download or Play Asset Delivery.

iOS: Info.plist -> <key>NSMicrophoneUsageDescription</key><string>Cette application utilise le micro pour la dictée vocale.</string>. Set platform :ios, '13.0' or higher in Podfile. No NSSpeechRecognitionUsageDescription needed (we never touch Apple's recognizer).

macOS: Info.plist -> NSMicrophoneUsageDescription (same as iOS). Entitlements: add <key>com.apple.security.device.audio-input</key><true/> to BOTH macos/Runner/DebugProfile.entitlements and Release.entitlements; add com.apple.security.network.client if models are downloaded at runtime (App Sandbox blocks networking otherwise).

WINDOWS: No manifest permission needed; mic access governed by Windows Settings > Privacy > Microphone (handle recorder.hasPermission() == false gracefully). x64 only for the native libs.

LINUX: No permission system. record's Linux backend requires PulseAudio tools at runtime (parecord/pactl; ffmpeg for some encoders) — works on PipeWire via pipewire-pulse. Document as a runtime dependency. sherpa_onnx ships prebuilt x64 .so via its linux sub-package.

MODELS (all platforms): on first launch download and extract the two model sets into getApplicationSupportDirectory(): (1) sherpa-onnx-streaming-zipformer-fr-2023-04-14 int8 files (~130 MB) for dictation, (2) sherpa-onnx-whisper-small int8 files (or tiny/base on mobile) for file transcription, from https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models. Show a progress UI; verify file sizes after download before first use.

## Notes API

ALL VERSIONS VERIFIED ON PUB.DEV 2026-07-14: sherpa_onnx 1.13.4, record 7.1.1, permission_handler 12.0.3, whisper_ggml 2.4.0, speech_to_text 7.4.0 (rejected), whisper_flutter_new 1.0.1 (rejected).

=== 1. INITIALIZATION (once, before any recognizer) ===
```dart
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
sherpa_onnx.initBindings(); // loads the native lib via FFI; call once at app start
```
The pub.dev `sherpa_onnx` package automatically pulls per-platform sub-packages (sherpa_onnx_android/ios/macos/linux/windows) — you only depend on `sherpa_onnx`.

=== 2. MODEL FILES (must be real files on disk — native code cannot read Flutter assets directly) ===
French live dictation (streaming transducer), download from GitHub releases (verified asset names, tag `asr-models` on k2-fsa/sherpa-onnx):
- https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-fr-2023-04-14.tar.bz2 (use `-mobile.tar.bz2` variant for smaller mobile build)
- Newer French option: sherpa-onnx-streaming-zipformer-fr-kroko-2025-08-06.tar.bz2
Archive contents (verified by extracting): encoder-epoch-29-avg-9-with-averaged-model.int8.onnx (127 MB; fp32 = 293 MB — ship int8), decoder-epoch-29-avg-9-with-averaged-model.int8.onnx (1.3 MB), joiner-epoch-29-avg-9-with-averaged-model.int8.onnx (0.26 MB), tokens.txt (5 KB). Total on-device ~130 MB int8.
File transcription (multilingual Whisper ONNX — French supported; do NOT pick `.en` archives):
- sherpa-onnx-whisper-tiny.tar.bz2 / -base / -small / -medium / -turbo / -distil-large-v3.5 (same release tag). Files inside follow pattern: `<size>-encoder.int8.onnx`, `<size>-decoder.int8.onnx`, `<size>-tokens.txt` (e.g. small-encoder.int8.onnx). Recommend `small` int8 for French quality/size balance; `tiny`/`base` for mobile.
Strategy: either (a) download+untar on first launch into `getApplicationSupportDirectory()` (add `archive` package or download pre-extracted files individually), or (b) bundle in flutter assets and copy to disk at startup:
```dart
Future<String> copyAssetFile(String src) async {
  final dir = await getApplicationSupportDirectory(); // path_provider
  final dst = p.join(dir.path, p.basename(src));
  final f = File(dst);
  if (!f.existsSync()) {
    final data = await rootBundle.load(src);
    await f.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }
  return dst;
}
```

=== 3. USE CASE A — LIVE FRENCH DICTATION (record 7.1.1 -> sherpa_onnx OnlineRecognizer) ===
```dart
final recognizer = sherpa_onnx.OnlineRecognizer(sherpa_onnx.OnlineRecognizerConfig(
  model: sherpa_onnx.OnlineModelConfig(
    transducer: sherpa_onnx.OnlineTransducerModelConfig(
      encoder: encPath, decoder: decPath, joiner: joinPath), // paths from step 2
    tokens: tokensPath,
    numThreads: 2, debug: false),
  ruleFsts: '',
  enableEndpoint: true,               // auto-detect end of utterance
  rule1MinTrailingSilence: 2.4,       // defaults verified in API docs
  rule2MinTrailingSilence: 1.2,
  rule3MinUtteranceLength: 20,
  decodingMethod: 'greedy_search', maxActivePaths: 4,
));
var stream = recognizer.createStream();

final recorder = AudioRecorder(); // package:record
if (await recorder.hasPermission()) {   // triggers OS mic prompt on mobile/macOS
  final pcm = await recorder.startStream(const RecordConfig(
    encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
  pcm.listen((data) {
    final samples = convertBytesToFloat32(Uint8List.fromList(data));
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    while (recognizer.isReady(stream)) { recognizer.decode(stream); }
    final partialText = recognizer.getResult(stream).text; // live partial result
    if (recognizer.isEndpoint(stream)) {
      // utterance finished -> commit partialText, then:
      recognizer.reset(stream);
    }
  });
}
// teardown: await recorder.stop(); stream.free(); recognizer.free();

Float32List convertBytesToFloat32(Uint8List bytes, [Endian endian = Endian.little]) {
  final values = Float32List(bytes.length ~/ 2);
  final data = ByteData.view(bytes.buffer);
  for (var i = 0; i < bytes.length; i += 2) {
    values[i ~/ 2] = data.getInt16(i, endian) / 32768.0;
  }
  return values;
}
```
This mirrors the official flutter-examples/streaming_asr app (github.com/k2-fsa/sherpa-onnx/tree/master/flutter-examples/streaming_asr), which itself uses `record`.

=== 4. USE CASE B — TRANSCRIBE RECORDED FILES (sherpa_onnx OfflineRecognizer + Whisper, French) ===
```dart
final recognizer = sherpa_onnx.OfflineRecognizer(sherpa_onnx.OfflineRecognizerConfig(
  model: sherpa_onnx.OfflineModelConfig(
    whisper: sherpa_onnx.OfflineWhisperModelConfig(
      encoder: 'small-encoder.int8.onnx path',
      decoder: 'small-decoder.int8.onnx path',
      language: 'fr',        // force French (skips autodetect, improves accuracy)
      task: 'transcribe'),   // verified params; also: tailPaddings, enableTokenTimestamps, enableSegmentTimestamps
    tokens: 'small-tokens.txt path',
    modelType: 'whisper', numThreads: 2, debug: false),
));
final wave = sherpa_onnx.readWave(wavPath); // 16-bit mono PCM WAV only!
final s = recognizer.createStream();
s.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
recognizer.decode(s);
final text = recognizer.getResult(s).text;
s.free(); recognizer.free();
```
GOTCHA: `readWave` reads only 16-bit mono WAV. Record your own audio with `record` using `AudioEncoder.wav, sampleRate: 16000, numChannels: 1` (recorder.start(config, path: ...)) so files are directly consumable. For arbitrary user files (m4a/mp3), decode to 16k mono WAV first (e.g. ffmpeg_kit_flutter on mobile/desktop, or ship ffmpeg CLI on desktop). sherpa-onnx resamples internally if sampleRate differs from 16k, but format must still be WAV/PCM. Whisper (non-streaming) processes up to 30s windows; for long recordings, chunk with sherpa_onnx VAD (sherpa_onnx.VoiceActivityDetector + silero_vad.onnx model, ~2MB, same release infra) and feed each voiced segment to the OfflineRecognizer — this is the standard sherpa-onnx pattern for long-file transcription.

=== 5. THREADING / PERFORMANCE ===
Inference is synchronous FFI — run OfflineRecognizer work in an isolate (Isolate.run) to avoid jank; the streaming decode loop per mic chunk is fast enough on the main isolate but an isolate is still cleaner. numThreads: 2-4 on desktop. Streaming FR model RTF is well under 1.0 on modern phones.

=== 6. KEY GOTCHAS ===
- Call sherpa_onnx.initBindings() exactly once before constructing anything, else FFI symbol lookup errors.
- Always pair createStream/free and recognizer/free — these are native allocations.
- getResult(stream).text on OnlineRecognizer returns the FULL partial for the current utterance (not a delta); after isEndpoint -> reset(stream) it starts empty again.
- record on Linux shells out to external tools (parecord/pactl; ffmpeg for some encoders) — document PulseAudio/PipeWire-pulse requirement for Linux users; streaming pcm16bits works but verify on target distro.
- record streaming supports only pcm16bits and aacLc encoders; use pcm16bits.
- Android: record requires minSdk 23.
- Do not ship fp32 model files; int8 halves size with negligible accuracy loss.
- French accuracy: streaming zipformer-fr trained on CommonVoice+ — good for dictation; Whisper small/medium gives the best French file-transcription quality.
- speech_to_text (7.4.0) is NOT suitable: no Linux, "device specific" OS recognition (can be cloud-backed), explicitly cannot transcribe audio files, designed for short commands not continuous dictation.
