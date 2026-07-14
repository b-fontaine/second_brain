# flutter_gemma package research: on-device LLM inference for Flutter (iOS, Android, Windows, Linux, macOS)

## Recommandation

flutter_gemma 1.2.3 (pub.dev, published 2026-07-12) + flutter_gemma_litertlm 1.1.0 (required engine for desktop; also runs mobile). Since v1.0 flutter_gemma is a modular core: you MUST add at least one engine package and register it via FlutterGemma.initialize(). For an app targeting iOS/Android/Windows/Linux/macOS with one code path, use .litertlm models via flutter_gemma_litertlm everywhere. Recommended models: Gemma 3 1B (0.5 GB, fast, gated HF repo) for text/chat; Gemma3n E2B (3.1 GB) or Gemma 4 E2B (2.4 GB) when vision/audio is needed. For RAG add flutter_gemma_embeddings 1.0.2 + flutter_gemma_rag_sqlite 1.1.0 (or _qdrant 1.1.0, native-only, faster).

## Support plateformes

{"android": true, "ios": true, "windows": true, "linux": true, "macos": true}

## Fallback

Desktop IS natively supported, so no separate fallback stack is needed — EXCEPT two architecture gaps: macOS Intel (x86_64) and Windows arm64 are NOT supported by flutter_gemma (typed error at native load; Android is arm64-v8a-only for .litertlm/embeddings). For those machines the pragmatic fallback is Ollama over localhost HTTP: `ollama_dart: ^2.4.0` (pub.dev, verified 2026-07-14; simple client for http://localhost:11434, chat + streaming + embeddings) or `langchain_ollama: ^0.4.1` — requires the user to install Ollama separately. A fully-embedded alternative is `llama_cpp_dart: ^0.2.2` (FFI bindings to llama.cpp, GGUF models, all desktop archs incl. Intel mac, but you must ship/build the llama.cpp dynamic library yourself and manage chat templating). Recommended detection: try FlutterGemma engine creation, catch the unsupported-architecture error, then degrade to Ollama HTTP if reachable.

## Entrées pubspec

- `flutter_gemma: ^1.2.3`
- `flutter_gemma_litertlm: ^1.1.0`
- `flutter_gemma_mediapipe: ^1.0.4  # optional - only if you also want .task/.bin models on mobile/web`
- `flutter_gemma_embeddings: ^1.0.2  # optional - text embeddings (EmbeddingGemma/Gecko)`
- `flutter_gemma_rag_sqlite: ^1.1.0  # optional - portable RAG vector store (all 6 platforms incl. web)`
- `flutter_gemma_rag_qdrant: ^1.1.0  # optional alternative - native-only qdrant-edge store (faster)`
- `flutter_gemma_agent: ^0.1.0  # optional - SKILL.md agent skills via function calling`

## Setup plateforme

iOS (any engine): Podfile `platform :ios, '16.0'` and `use_frameworks! :linkage => :static`. Info.plist: UIFileSharingEnabled=true, NSLocalNetworkUsageDescription (dev), optional CADisableMinimumFrameDurationOnPhone=true. Runner.entitlements (large models): com.apple.developer.kernel.extended-virtual-addressing, com.apple.developer.kernel.increased-memory-limit, com.apple.developer.kernel.increased-debugging-memory-limit (all true). No post_install needed on iOS.

Android: minSdk 24, compileSdk 36. For GPU add to AndroidManifest.xml inside <application>: <uses-native-library android:name="libvndksupport.so" android:required="false"/>, libOpenCL.so, libOpenCL-car.so, libOpenCL-pixel.so (all required=false). For large downloads (API 34+): <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>, <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/> and <service android:name="androidx.work.impl.foreground.SystemForegroundService" android:foregroundServiceType="dataSync" tools:node="merge"/>. Restrict ABIs: ndk { abiFilters 'arm64-v8a' } if using .litertlm/embeddings/vision. MediaPipe engine ships its own ProGuard consumer rules.

macOS (Apple Silicon only): paste the flutter_gemma post_install block into macos/Podfile (copies the 3 Apple accelerator dylibs — libGemmaModelConstraintProvider/libLiteRtMetalAccelerator/libLiteRtTopKMetalSampler — into App Frameworks as .framework bundles and patches LiteRtLm.dylib's LC_LOAD_DYLIB; full script in README 'macOS Setup') then `pod install`. Add to DebugProfile.entitlements AND Release.entitlements: com.apple.security.cs.disable-library-validation=true. (App Sandbox network-client + user-selected file entitlements as usual for downloads/file picking.)

Windows (x86_64 only): zero config — Native Assets hook downloads LiteRtLm.dll + DXC runtime (dxil.dll, dxcompiler.dll v1.9.2602) on first build, SHA256-verified. End users need MSVC++ Redistributable 2019+.

Linux (x86_64/arm64): build deps `sudo apt install clang cmake ninja-build libgtk-3-dev lld`; GPU needs a real vendor Vulkan driver (NVIDIA/AMD/Intel) — Mesa llvmpipe won't run Gemma 4 (128MB maxStorageBufferRange cap).

Memory: multimodal models want 8GB+ RAM devices; use 1B-2B models under 6GB RAM; iOS large models require the memory entitlements above; each extra open session ~100-500MB.

Web (if ever targeted): add to web/index.html the MediaPipe CDN script (@mediapipe/tasks-genai@0.10.27 assigning window.FilesetResolver/LlmInference) and/or @litert-lm/core@0.12.1 handshake; GPU-only; WebStorageMode.streaming for >2GB models.

## Notes API

ALL facts verified 2026-07-14 on pub.dev + github.com/DenisovAV/flutter_gemma (README at packages/flutter_gemma/README.md — the repo is a monorepo; the root has no README) + fluttergemma.dev docs + source (lib/flutter_gemma_interface.dart, core/api/flutter_gemma.dart, core/message.dart, core/tool.dart).

== VERSIONS (pub.dev API, 2026-07-14) ==
flutter_gemma 1.2.3 (2026-07-12) | flutter_gemma_litertlm 1.1.0 (2026-07-13) | flutter_gemma_mediapipe 1.0.4 | flutter_gemma_embeddings 1.0.2 | flutter_gemma_rag_qdrant 1.1.0 | flutter_gemma_rag_sqlite 1.1.0 | flutter_gemma_agent 0.1.0. SDK constraints: Dart >=3.12.0 <4.0.0, Flutter >=3.44.0. pub.dev platform badges: Android, iOS, Linux, macOS, Web, Windows. 405 likes, 24.6k weekly downloads.

== PLATFORM SUPPORT (critical detail) ==
Desktop is FULLY SUPPORTED (since 0.15/1.0) via flutter_gemma_litertlm — LiteRT-LM C API called through dart:ffi in-process (no JVM, no server). GPU: macOS Metal, Windows DirectX 12, Linux Vulkan. NPU: Android Qualcomm Snapdragon + Windows Intel LunarLake/PantherLake.
Architecture matrix: Android arm64-v8a (full; .task text-only also works on x86_64/armeabi-v7a, but .litertlm+embeddings+vision are arm64-only — add `ndk { abiFilters 'arm64-v8a' }`); iOS device arm64; iOS Simulator arm64 (Apple Silicon host) CPU-only; macOS arm64 ONLY (Intel NOT supported); Windows x86_64 ONLY (arm64 NOT supported); Linux x86_64 + arm64.
Model formats: `.task`/`.bin` = MediaPipe engine, mobile+web ONLY, NOT desktop. `.litertlm` = LiteRT-LM engine, Android/iOS/desktop (+ early-preview web, text-only). Desktop = .litertlm exclusively. Web = GPU-only (no CPU backend), Safari effectively unusable (~50 MB cache cap); web .litertlm preview has NO vision/audio/thinking/function-calling.
Desktop model storage: Windows %LOCALAPPDATA%\flutter_gemma\, macOS ~/Library/Application Support/<bundle>/flutter_gemma/, Linux ~/.local/share/<app>/flutter_gemma/ (deliberately outside Documents to avoid OneDrive/iCloud corrupting mmap).

== MODELS (name | size | desktop/mobile/web | notes) ==
Gemma 3 1B (litert-community/Gemma3-1B-IT) | 0.5GB | ✅/✅/✅ | best default for text; function calling; GATED (needs HF token).
Gemma 3 270M | 0.3GB | ✅/✅/✅ | tiny, LoRA fine-tune target; gated.
Gemma3n E2B (google/gemma-3n-E2B-it-litert-lm or -litert-preview) | 3.1GB | ✅/✅/✅ | vision+audio+function calling; gated; needs 8GB+ RAM.
Gemma3n E4B | 6.5GB | ✅/✅/✅ | same, bigger.
Gemma 4 E2B (litert-community/gemma-4-E2B-it-litert-lm) | 2.4GB | ✅/✅/✅ | vision+audio+thinking+native function calling (ModelType.gemma4).
Gemma 4 E4B | 4.3GB | ✅/✅/✅.
Qwen3 0.6B | 586MB | ✅/✅/✅ | public, function calling + thinking.
DeepSeek R1 Distill 1.5B | 1.7GB | ❌ desktop /✅/❌ | thinking mode.
FastVLM 0.5B | 0.5GB | ✅ desktop-only vision model.
Phi-4 Mini 3.9GB ✅/✅/✅; Qwen2.5 1.5B 1.6GB ✅/✅/❌; SmolLM 135M mobile-only.
Canonical download URL pattern: https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm (use /resolve/, NOT /blob/).

== INIT (mandatory since 1.0) ==
```dart
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';
import 'package:flutter_gemma_rag_sqlite/flutter_gemma_rag_sqlite.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize(
    inferenceEngines: const [LiteRtLmEngine()],      // from flutter_gemma_litertlm
    embeddingBackends: const [LiteRtEmbeddingBackend()], // from flutter_gemma_embeddings
    vectorStore: SqliteVectorStore(),                // or QdrantVectorStore() / WebSqliteVectorStore()
    huggingFaceToken: const String.fromEnvironment('HUGGINGFACE_TOKEN'),
    maxDownloadRetries: 10,
  );
  runApp(MyApp());
}
```
GOTCHA: core registers NO engine — omit inferenceEngines and getActiveModel() throws StateError('add the engine package').

== MODEL DOWNLOAD / INSTALL (Modern API; ModelFileManager is the deprecated legacy path) ==
```dart
await FlutterGemma.installModel(modelType: ModelType.gemmaIt)   // gemma4|gemmaIt|deepSeek|qwen|qwen3|functionGemma|phi|general
  .fromNetwork(url, token: 'hf_...')     // or .fromAsset('models/m.litertlm') / .fromBundled('m.litertlm') / .fromFile(path)
  .withProgress((int p) => print('$p%')) // 0-100
  .withCancelToken(cancelToken)          // optional CancelToken from core/model_management/cancel_token.dart
  .install();
final installed = await FlutterGemma.isModelInstalled('Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm');
await FlutterGemma.uninstallModel(id); await FlutterGemma.clearActiveInferenceIdentity();
```
Errors: catch DownloadException, sealed e.error: UnauthorizedError(401)/ForbiddenError(403 gated repo)/NotFoundError(404)/RateLimitedError/ServerError/NetworkError/CanceledError; helpers toUserMessage(), isRetryable. Android: downloads >500MB auto-use foreground service; on API 34+ the HOST APP must declare FOREGROUND_SERVICE_DATA_SYNC permission + override androidx.work SystemForegroundService foregroundServiceType="dataSync" (tools:node="merge"), plus POST_NOTIFICATIONS. HuggingFace CDN does NOT support resume (restarts instead). Gated repos (all Gemma models, EmbeddingGemma) need an HF token + one-time 'Request Access' on the repo page; DeepSeek/Qwen/Phi/SmolLM/FastVLM are public.

== INFERENCE ==
```dart
final model = await FlutterGemma.getActiveModel(
  maxTokens: 2048,                 // CONTEXT WINDOW (input+output). .litertlm min 1024 (auto-clamped)
  preferredBackend: PreferredBackend.gpu,  // .cpu / .gpu ; check model.activeBackend for silent fallback
  supportImage: true, supportAudio: false, maxNumImages: 1,
  maxConcurrentSessions: 3);
final chat = await model.createChat(
  temperature: 0.8, randomSeed: 1, topK: 1, topP: null, tokenBuffer: 256,
  systemInstruction: 'You are a concise assistant.',   // native on .litertlm Android/desktop; prepended-to-first-message fallback on .task/iOS/web
  tools: [Tool(name: 'get_weather', description: '...', parameters: {/*JSON schema*/})],
  toolChoice: ToolChoice.auto,     // auto|required|none
  supportsFunctionCalls: true, isThinking: false, modelType: ModelType.gemmaIt,
  maxOutputTokens: 500);           // caps GENERATED tokens; honored on .litertlm, ignored by MediaPipe .task
await chat.addQueryChunk(Message.text(text: 'Hello', isUser: true));
final resp = await chat.generateChatResponse();        // ModelResponse (await full reply)
chat.generateChatResponseAsync().listen((r) {          // STREAMING
  if (r is TextResponse) append(r.token);
  else if (r is FunctionCallResponse) { r.name; r.args; /* run fn then: */
    chat.addQueryChunk(Message.toolResponse(toolName: r.name, response: {'ok': true})); }
  else if (r is ThinkingResponse) showReasoning(r.content); });
await chat.session.stopGeneration(); // cancel mid-generation (portable); model.close() to free
```
Low-level: model.createSession(...)/openSession(...) → session.getResponse():Future<String>, session.getResponseAsync():Stream<String> (raw tokens), addQueryChunk(Message), sizeInTokens(text), stopGeneration(), getSessionMetrics() (inputTokens/outputTokens/timeToFirstTokenMs/tokensPerSecond). openChat()/openSession() = concurrent independent contexts sharing one loaded weight set; generation is SERIALIZED (one at a time); each session costs ~100-500MB.
Multiple instances: getActiveModel() can be called repeatedly with different maxTokens against the same installed file.

== MULTIMODAL ==
Vision: Gemma 4 E2B/E4B, Gemma3n E2B/E4B, FastVLM. Works on ALL platforms incl. desktop (verified macOS Metal + Linux Vulkan) and web .task. Set supportImage:true on BOTH getActiveModel and createChat. Message.withImage(text:,imageBytes:Uint8List), Message.withImages(text:,imageBytes:List<Uint8List>), Message.imageOnly/imagesOnly; JPEG/PNG handled automatically; message.hasImage. OCR-like reading: no dedicated OCR API — Gemma3n/Gemma 4 vision can describe and read text in images reasonably ('What text is in this image?'), but for production-grade OCR pair with google_mlkit_text_recognition (mobile) or run vision-prompt extraction and validate; treat LLM-vision OCR as best-effort.
Audio input: Gemma 4 + Gemma3n E2B/E4B only. Android ✅, iOS physical device ✅ (not simulator), desktop ✅ (.litertlm), Web ❌. supportAudio:true + Message.withAudio(text:, audioBytes:) / Message.audioOnly(audioBytes:). Recording is app-side (e.g. record package); pass WAV/PCM bytes.
Thinking mode: Gemma 4/DeepSeek/Qwen3, isThinking:true (+ matching ModelType), stream yields ThinkingResponse; NOT on web.

== EMBEDDINGS + RAG (yes, built-in) ==
768-dim embeddings via flutter_gemma_embeddings on all native platforms + web. Models: EmbeddingGemma-300m seq256 (179MB, gated, best quality, ~286ms/doc on Pixel 8 GPU) or Gecko-110m-en (110MB, public, ~109ms/doc). Install: FlutterGemma.installEmbedder().modelFromNetwork('https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq256_mixed-precision.tflite', token: hf).tokenizerFromNetwork('https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/sentencepiece.model', token: hf).install(); then final e = await FlutterGemma.getActiveEmbedder(); await e.generateEmbedding(text, taskType: TaskType.retrievalQuery) / generateEmbeddings(texts, taskType: TaskType.retrievalDocument) / getDimension().
RAG store: FlutterGemmaPlugin.instance.initializeVectorStore('rag_store'); addDocument(id:,content:,metadata:'{"k":"v"}') (auto-embeds) or addDocumentWithEmbedding(...); searchSimilar(query:, topK:10, threshold:0.0, filter: Filter(must:[FieldEquals(key:'category',value:'science')])) → List<RetrievalResult>. sqlite store works on all 6 platforms; qdrant-edge native-only. filterSchema: FilterSchema(...) must be passed to initialize() to make metadata fields filterable.

== GOTCHAS ==
1) maxTokens is context window, NOT reply length — use maxOutputTokens for that. 2) Desktop cannot load .task/.bin — always ship .litertlm URLs if desktop is a target. 3) DeepSeek R1 + SmolLM have NO desktop build. 4) macOS Intel and Windows arm64 unsupported. 5) LoRA not supported on desktop (LiteRT-LM limitation). 6) Flutter assets + bundled resources not supported on desktop — use fromNetwork or fromFile. 7) Native libs are fetched at BUILD time by Native Assets hook/build.dart (needs network on first build; SHA256-verified). 8) Release builds silence all plugin logs; debug: FlutterGemma.logLevel = GemmaLogLevel.verbose. 9) Web needs Flutter >=3.44/Dart >=3.12 toolchain anyway per pubspec.
