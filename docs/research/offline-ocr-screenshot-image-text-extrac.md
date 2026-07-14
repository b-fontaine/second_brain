# Offline OCR (screenshot/image text extraction) for Flutter on iOS, Android, Windows, Linux, macOS + image import (picker/clipboard), with French support

## Recommandation

Hybrid per-platform stack behind one Dart interface: google_mlkit_text_recognition ^0.16.0 (Android+iOS, Latin script incl. French), custom ~40-line Vision (VNRecognizeTextRequest) method channel on macOS (fr-FR language hints; the pub.dev Apple Vision plugins are stale or lack language config), platform_ocr ^1.0.0 on Windows (Windows.Media.Ocr, uses user-profile language packs), and the system `tesseract` CLI via Process.run on Linux (tesseract-ocr-fra). Image import: image_picker ^1.2.3 + file_selector ^1.1.0 + pasteboard ^0.5.0 (clipboard paste). flutter_gemma ^1.2.3 (Gemma 3n vision) is viable only as an optional semantic fallback, not primary OCR.

## Support plateformes

{"android": true, "ios": true, "windows": true, "linux": true, "macos": true}

## Fallback

Two fallback layers: (1) Tesseract everywhere — flutter_tesseract_ocr ^0.4.31 covers Android/iOS/web only; on desktop use system tesseract CLI (Linux/macOS via brew/apt, Windows via UB-Mannheim installer) with fra+eng traineddata, ~85-95% accuracy on clean screenshots, worse than native engines. flusseract ^0.1.3 is an FFI Tesseract for all 5 platforms but builds Tesseract from source via CMake at build time, is 2 years stale (Apr 2024) and has ~73 downloads — high build risk, use only if in-process Linux OCR becomes mandatory. (2) flutter_gemma ^1.2.3 with Gemma 3n E2B vision (3.1GB .litertlm) runs on all 5 platforms and can transcribe text from images, but: seconds-to-minutes latency, 4-6GB RAM, hallucinates/normalizes text instead of verbatim transcription, no bounding boxes, gated HuggingFace download needs token + license acceptance. Verdict: NOT suitable as primary OCR; acceptable as last-resort fallback or for post-OCR enrichment (summarize/tag/translate the extracted text). If OCR fails on Windows because no OCR language pack is installed, prompt the user to run: Add-WindowsCapability -Online -Name "Language.OCR~~~fr-FR~0.0.1.0"; on Linux prompt: sudo apt install tesseract-ocr tesseract-ocr-fra tesseract-ocr-eng.

## Entrées pubspec

- `google_mlkit_text_recognition: ^0.16.0`
- `platform_ocr: ^1.0.0  # Windows backend (also works macOS/iOS; used only on Windows in our stack)`
- `image_picker: ^1.2.3`
- `file_selector: ^1.1.0`
- `pasteboard: ^0.5.0`
- `path_provider: ^2.1.5  # temp files for bytes->file normalization`
- `flutter_gemma: ^1.2.3  # OPTIONAL — only if Gemma semantic fallback/enrichment is wanted (3.1GB model)`

## Setup plateforme

ANDROID: minSdk 21 (ML Kit), compileSdk/targetSdk 35. No manifest changes for OCR or image_picker. If pasteboard clipboard-image is used on Android: add FileProvider to AndroidManifest.xml + res/xml/provider_paths.xml per pasteboard README. If flutter_gemma GPU: <uses-native-library android:name="libOpenCL.so" android:required="false"/> + libvndksupport.so in <application>.
iOS: Podfile platform :ios, '15.5' (ML Kit requirement; 16.0 if flutter_gemma included). Xcode 15.3+, 64-bit only. Info.plist: NSPhotoLibraryUsageDescription (image_picker, required), NSCameraUsageDescription only if camera capture added. flutter_gemma additionally: UIFileSharingEnabled, and Runner.entitlements com.apple.developer.kernel.increased-memory-limit + extended-virtual-addressing.
macOS: deployment target 10.15+ (Vision), 13+ recommended for automaticallyDetectsLanguage. Entitlements (both DebugProfile and Release): com.apple.security.files.user-selected.read-only (file_selector/image_picker); com.apple.security.network.client if downloading Gemma models. Add the ~40-line Swift Vision method channel to macos/Runner (code in api_notes section 3) — no CocoaPod needed, Vision.framework is system.
WINDOWS: Windows 10+ (Windows.Media.Ocr is WinRT). Build machine: VS2022 with 'Desktop development with C++' AND 'C++/WinRT' workloads (platform_ocr native-assets build). Runtime: user must have an OCR language pack for French — preinstalled on French Windows; else admin PowerShell: Add-WindowsCapability -Online -Name "Language.OCR~~~fr-FR~0.0.1.0". Verify platform_ocr's example builds in CI first (v1.0.0, native assets); fallback plan is a custom C++/WinRT channel (sketch in api_notes section 4).
LINUX: no build-time deps for OCR (CLI approach). Runtime deps: tesseract-ocr, tesseract-ocr-fra, tesseract-ocr-eng (apt) / tesseract + tesseract-langpack-fra (dnf). Detect via `which tesseract` and show install instructions in-app when missing. Standard Flutter Linux GTK deps otherwise.
ALL PLATFORMS: normalize every input (picker XFile, clipboard Uint8List) to a temp PNG file via path_provider before calling the OCR backend — ML Kit InputImage.fromBytes does NOT accept PNG/JPEG bytes (raw NV21/BGRA8888 only), and file paths are the one input every backend supports.

## Notes API

ALL VERSIONS VERIFIED ON PUB.DEV 2026-07-14.

=== 1. ABSTRACT INTERFACE (recommended design) ===
```dart
abstract interface class OcrService {
  Future<OcrResult> recognizeFile(String imagePath);           // primary entry point
  Future<OcrResult> recognizeBytes(Uint8List pngOrJpegBytes);  // default impl: write to temp file, call recognizeFile
  Future<bool> isAvailable();                                   // e.g. Linux: `which tesseract`
}
class OcrResult { final String text; final List<OcrBlock> blocks; } // blocks may be empty on Windows/Linux
class OcrBlock { final String text; final Rect? boundingBox; final List<String> languages; }
```
Factory: `OcrService createOcr() => switch (defaultTargetPlatform) { android || iOS => MlKitOcr(), macOS => VisionOcr(), windows => WindowsOcr(), linux => TesseractCliOcr(), _ => throw UnsupportedError(...) }`. IMPORTANT: clipboard/picker sources give you bytes or paths; normalize to a temp PNG file path — every backend accepts file paths, and ML Kit's fromBytes does NOT accept PNG (see gotcha below).

=== 2. ANDROID + iOS: google_mlkit_text_recognition 0.16.0 (published 2026-07-07, mobile ONLY — pub.dev tags platform:android, platform:ios; ML Kit is not built for desktop/web) ===
On-device, fully offline, model bundled in APK/IPA (no Play Services download for the bundled variant). TextRecognitionScript.latin covers French incl. accents (é à ç œ); RecognizedText exposes per-block recognizedLanguages.
```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
final recognizer = TextRecognizer(script: TextRecognitionScript.latin); // latin is default
final inputImage = InputImage.fromFilePath(imagePath); // ALWAYS use file path for screenshots
final RecognizedText result = await recognizer.processImage(inputImage);
final fullText = result.text; // whole recognized text
for (final block in result.blocks) {
  block.text; block.boundingBox /*Rect*/; block.recognizedLanguages; // e.g. ['fr']
  for (final line in block.lines) { for (final el in line.elements) { el.text; } }
}
await recognizer.close(); // REQUIRED — frees native recognizer; keep one instance, close on dispose
```
GOTCHA: `InputImage.fromBytes` only accepts RAW camera formats (NV21 on Android, BGRA8888 on iOS) + explicit InputImageMetadata — it will fail or return garbage for PNG/JPEG bytes. For clipboard bytes: `final f = File('${(await getTemporaryDirectory()).path}/ocr.png'); await f.writeAsBytes(bytes); InputImage.fromFilePath(f.path);`
Constraints: Android minSdk 21, compileSdk 35. iOS min deployment target 15.5, Xcode 15.3+, 64-bit only (exclude armv7 — add to Podfile: `config.build_settings['EXCLUDED_ARCHS[sdk=iphoneos*]'] = 'armv7'` inside post_install if needed). ML Kit works on iOS simulator arm64.

=== 3. macOS: custom Vision method channel (RECOMMENDED — write it, don't depend) ===
Why custom: apple_vision_recognize_text 0.0.4 is 2 years stale (2024-06), camera-stream-oriented, and does not expose recognitionLanguages; platform_ocr 1.0.0 works on macOS but has NO language hints (Vision then defaults to en-US — bad for French accents). ~40 lines of Swift gives full control:
```swift
// macos/Runner/MainFlutterWindow.swift (or a dedicated plugin class), register in awakeNib/applicationDidFinishLaunching:
import FlutterMacOS
import Vision
let channel = FlutterMethodChannel(name: "app/ocr", binaryMessenger: controller.engine.binaryMessenger)
channel.setMethodCallHandler { call, result in
  guard call.method == "recognize", let args = call.arguments as? [String: Any],
        let path = args["path"] as? String else { result(FlutterMethodNotImplemented); return }
  DispatchQueue.global(qos: .userInitiated).async {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["fr-FR", "en-US"]      // French first
    if #available(macOS 13.0, *) { request.automaticallyDetectsLanguage = true }
    let handler = VNImageRequestHandler(url: URL(fileURLWithPath: path), options: [:])
    do {
      try handler.perform([request])
      let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
      DispatchQueue.main.async { result(text) }
    } catch { DispatchQueue.main.async { result(FlutterError(code: "OCR_FAILED", message: error.localizedDescription, details: nil)) } }
  }
}
```
```dart
static const _ch = MethodChannel('app/ocr');
final text = await _ch.invokeMethod<String>('recognize', {'path': imagePath});
```
Vision OCR needs macOS 10.15+ (language correction quality much better on 12+; auto language detection needs 13+). Same Swift works on iOS (iOS 13+) if you ever want to drop ML Kit there. Bounding boxes available via observation.boundingBox (normalized, origin bottom-left — flip Y).

=== 4. WINDOWS: platform_ocr 1.0.0 (published 2025-12-29, repo github.com/kikuchy/platform_ocr; supports Windows/macOS/iOS, NOT Android/Linux) ===
Wraps Windows.Media.Ocr via C++/WinRT with a C ABI + Dart Native Assets (build hooks). Requires Flutter 3.13+ with native-assets support and VS2022 with "Desktop development with C++" + C++/WinRT components.
```dart
import 'package:platform_ocr/platform_ocr.dart';
final ocr = PlatformOcr();
final text = await ocr.recognizeText(OcrSource.file(File(imagePath)));       // returns String
final text2 = await ocr.recognizeText(OcrSource.memory(pngBytes));           // bytes decoded via package:image to RGBA8
```
Documented limitations (roadmap): no language hints, no fast/accurate toggle, no bounding boxes. Windows.Media.Ocr picks the engine from the user's installed OCR language packs (user profile languages) — a French Windows install has fr-FR OCR out of the box; otherwise install via `Add-WindowsCapability -Online -Name "Language.OCR~~~fr-FR~0.0.1.0"` (admin PowerShell) or Settings > Time & Language > add French. French accuracy with the fr pack is good (it's the engine behind Windows' own screenshot OCR).
RISK NOTE: single maintainer, v1.0.0, native-assets build path — validate its example app builds in your CI early. Plan B if it doesn't fly: write a custom C++/WinRT method channel (OcrEngine::TryCreateFromLanguage(Language(L"fr")) → SoftwareBitmap from file via BitmapDecoder → engine.RecognizeAsync(bitmap).get().Text()); ~100 lines in windows/runner/flutter_window.cpp. Rejected: windows_ocr 0.0.1 (5 years old, Dart-3 incompatible).

=== 5. LINUX: system Tesseract CLI (no viable maintained plugin) ===
flutter_tesseract_ocr 0.4.31 tags are android/ios/web only; flusseract 0.1.3 (all 5 platforms) builds Tesseract from source via CMake and is stale — avoid. Pragmatic approach:
```dart
class TesseractCliOcr implements OcrService {
  @override Future<bool> isAvailable() async =>
    (await Process.run('which', ['tesseract'])).exitCode == 0;
  @override Future<OcrResult> recognizeFile(String path) async {
    final r = await Process.run('tesseract', [path, 'stdout', '-l', 'fra+eng', '--psm', '3'],
        stdoutEncoding: utf8);
    if (r.exitCode != 0) throw OcrException(r.stderr.toString());
    return OcrResult(text: (r.stdout as String).trim(), blocks: const []);
  }
}
```
User needs `sudo apt install tesseract-ocr tesseract-ocr-fra tesseract-ocr-eng` (Fedora: tesseract tesseract-langpack-fra). Surface a friendly setup prompt when isAvailable() is false. Optionally support TESSDATA_PREFIX env override. For bounding boxes later: `tesseract path stdout -l fra+eng tsv` and parse TSV.

=== 6. GEMMA 3n VISION via flutter_gemma 1.2.3 (published 2026-07-12) — EVALUATED, NOT RECOMMENDED AS PRIMARY OCR ===
Supports Android/iOS/Windows/Linux/macOS/web; Gemma 3n E2B multimodal = 3.1GB (.litertlm required on desktop; .task mobile/web only). Init: `FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine(), MediaPipeEngine()], huggingFaceToken: 'hf_...')`; install: `FlutterGemma.installModel(modelType: ModelType.gemmaIt).fromNetwork('https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.litertlm', token: 'hf_...').install()`; use: `final model = await FlutterGemma.getActiveModel(maxTokens: 2048, supportImage: true); final chat = await model.createChat(); await chat.addQueryChunk(Message.withImages(text: 'Transcris exactement le texte de cette image.', imageBytes: [png], isUser: true)); final resp = await chat.generateChatResponse();`. Requirements: iOS 16+ with increased-memory-limit + extended-virtual-addressing entitlements; Android GPU needs uses-native-library libOpenCL.so declarations; Windows needs VC++ Redistributable 2019+; gated HF repo (token + Gemma license). OCR verdict: reads large clean text OK but hallucinates/paraphrases on dense screenshot text, ~5-60s per image, no bounding boxes, 3.1GB download, 4-6GB RAM. Use dedicated OCR for extraction; optionally feed OCR output (not the image) to Gemma for tagging/summarizing in a second-brain context.

=== 7. IMAGE IMPORT ===
image_picker 1.2.3 (flutter.dev verified, published 2026-06-30) — Android SDK 21+ (works out of the box, no manifest changes; handle `ImagePicker().retrieveLostData()` on Android for low-memory Activity death), iOS 13+ (Info.plist: NSPhotoLibraryUsageDescription required; NSCameraUsageDescription only if camera used), Linux/macOS 10.15+/Windows 10+ (desktop implementations delegate to file_selector — gallery source opens a file dialog; ImageSource.camera needs a cameraDelegate, skip it on desktop).
```dart
final XFile? img = await ImagePicker().pickImage(source: ImageSource.gallery);
if (img != null) { final path = img.path; final bytes = await img.readAsBytes(); }
```
file_selector 1.1.0 (flutter.dev, 2025-11-21) — use directly on desktop for finer control:
```dart
const group = XTypeGroup(label: 'Images', extensions: ['png','jpg','jpeg','webp','bmp','tiff'],
    uniformTypeIdentifiers: ['public.image']); // UTIs needed for macOS
final XFile? file = await openFile(acceptedTypeGroups: [group]);
```
macOS REQUIRES sandbox entitlement in BOTH macos/Runner/DebugProfile.entitlements and Release.entitlements: `<key>com.apple.security.files.user-selected.read-only</key><true/>`.
pasteboard 0.5.0 (mixin.dev verified, published 2026-02-24) — clipboard image paste on Windows/Linux/macOS/iOS/web/Android:
```dart
import 'package:pasteboard/pasteboard.dart';
final Uint8List? bytes = await Pasteboard.image; // null if clipboard has no image
```
Android needs a FileProvider entry in AndroidManifest.xml + res/xml/provider_paths.xml (see package README; error 'Couldn't find meta-data for provider' if missing) — but on Android you'll rarely paste screenshots, picker + share-intent matter more. Wire Ctrl/Cmd+V via a `Shortcuts`/`CallbackShortcuts` widget on desktop. Alternative if pasteboard proves flaky on Linux (X11 vs Wayland quirks): super_clipboard 0.9.1 (Rust-based, converts DIB/TIFF→PNG automatically, heavier toolchain: Rustup + NDK on Android, minSdk 23).

=== 8. REJECTED PACKAGES (with reasons — do not revisit) ===
- tesseract_ocr 0.5.0: Android/iOS only, superseded by flutter_tesseract_ocr.
- flutter_tesseract_ocr 0.4.31 as primary: mobile+web only, ML Kit beats it on both quality and setup (its own README says so); traineddata assets (assets/tessdata/fra.traineddata + tessdata_config.json) add app size. Keep only if you need exotic scripts on mobile.
- apple_vision / apple_vision_recognize_text 0.0.4: iOS 13+/macOS 10.15+ but stale (2024-06), camera-stream API shape, no exposed recognitionLanguages → French risk.
- unified_apple_vision: broader Vision wrapper, still less code than needed vs the 40-line custom channel.
- windows_ocr 0.0.1: 5 years old, Dart 3 incompatible.
- flutter_ocr_native 0.3.0 (2026-06-08): tempting all-5-platform abstraction (ML Kit/Vision/WinRT/Tesseract) — but explicitly ENGLISH-ONLY with non-Latin auto-filtering (kills French accents), unverified publisher, 264 downloads. Steal its architecture, not the dependency.
- flusseract 0.1.3: see fallback section.

=== 9. TESTING NOTES ===
Test corpus must include: French screenshots with accents (é è à ç ù œ «») , dark-mode screenshots (white-on-black — all engines handle, Tesseract benefits from pre-inversion), mixed FR/EN. Assert accented words survive round-trip on every platform (this is exactly where the wrong default language silently corrupts: 'déjà' → 'deja').
