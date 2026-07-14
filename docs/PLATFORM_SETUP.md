# Configuration native par plateforme

Cumul des exigences des briefs `docs/research/*.md` (flutter_gemma, git2dart,
sherpa_onnx/record, OCR). Tout ce qui est listé « déjà appliqué » est commité
dans le dépôt ; les étapes « manuelles » restent à faire par le développeur.

## Limites d'architecture (toutes plateformes)

| Plateforme | IA locale (flutter_gemma / LiteRT-LM) |
|---|---|
| Android | arm64-v8a uniquement (APK restreint via `abiFilters`) |
| iOS | arm64 (device) ; simulateur arm64 CPU-only |
| macOS | **Apple Silicon uniquement — macOS Intel non supporté** |
| Windows | **x64 uniquement — Windows arm64 non supporté** |
| Linux | x64 et arm64 |

Sur macOS Intel et Windows arm64, le chargement natif échoue avec une erreur
typée : l'app doit dégrader en mode « sans assistant IA » (voir DECISIONS.md).
Fallback possible : Ollama via HTTP localhost (non implémenté par défaut).

---

## Android

### Déjà appliqué

- `android/app/build.gradle.kts` :
  - `minSdk = 24` (exigence LiteRT-LM ; `record` exige 23, ML Kit 21 — 24 couvre tout) ;
  - `ndk { abiFilters += listOf("arm64-v8a") }` — les modèles `.litertlm`,
    les embeddings et la vision sont arm64-only. Conséquence assumée : pas de
    build x86_64 (émulateurs Intel) ni armeabi-v7a.
- `android/app/src/main/AndroidManifest.xml` :
  - permissions : `INTERNET` (git sync + téléchargements), `RECORD_AUDIO`
    (dictée), `POST_NOTIFICATIONS` + `FOREGROUND_SERVICE_DATA_SYNC`
    (téléchargements de modèles >500 Mo via WorkManager, requis API 34+) ;
  - `<uses-native-library>` OpenCL (`libOpenCL.so`, `libOpenCL-car.so`,
    `libOpenCL-pixel.so`, `libvndksupport.so`), tous `required="false"` —
    délégué GPU optionnel pour l'inférence ;
  - `<service androidx.work.impl.foreground.SystemForegroundService>` avec
    `foregroundServiceType="dataSync"` et `tools:node="merge"` (namespace
    `xmlns:tools` ajouté sur `<manifest>`).

### Étapes manuelles

- `RECORD_AUDIO` et `POST_NOTIFICATIONS` sont demandées au runtime par
  l'app (permission_handler) — rien à faire.
- **Signature release** (obligatoire avant toute distribution) :
  `android/app/build.gradle.kts` lit `android/key.properties` (gitignoré).
  Sans ce fichier, le build release retombe sur la clé de **debug** — jamais
  distribuable (clé publique connue de tous, refusée par le Play Store, et
  impossible à changer ensuite sans casser l'identité de l'app).

  1. Générer un keystore privé (à sauvegarder hors du dépôt, ne jamais le
     commiter ni le partager) :

     ```bash
     keytool -genkey -v -keystore ~/upload-keystore.jks \
       -keyalg RSA -keysize 2048 -validity 10000 \
       -alias upload
     ```

  2. Créer `android/key.properties` :

     ```properties
     storePassword=<mot de passe du keystore>
     keyPassword=<mot de passe de la clé>
     keyAlias=upload
     storeFile=/chemin/absolu/vers/upload-keystore.jks
     ```

  `key.properties`, `*.jks` et `*.keystore` sont déjà couverts par
  `android/.gitignore`. Référence : https://docs.flutter.dev/deployment/android#sign-the-app
- Pièges connus : `git2dart` nécessite `PlatformSpecific.initialize()` dans
  `main()` **avant** tout appel git (extraction des certificats CA sur
  Android) ; `pasteboard` (collage d'image) exigerait un FileProvider dans le
  manifest — non ajouté car le collage presse-papiers est un flux desktop.

---

## iOS

### Déjà appliqué

- `ios/Podfile` : `platform :ios, '16.0'` (flutter_gemma) et
  `use_frameworks! :linkage => :static`.
- `ios/Runner/Info.plist` :
  - `NSMicrophoneUsageDescription` = « Micro utilisé pour la dictée de notes » ;
  - `NSPhotoLibraryUsageDescription` = « Import de captures d'écran » ;
  - `UIFileSharingEnabled` = true (vault visible dans l'app Fichiers) ;
  - `CADisableMinimumFrameDurationOnPhone` (déjà présent, recommandé par flutter_gemma).
- `ios/Runner/Runner.entitlements` (créé) :
  - `com.apple.developer.kernel.increased-memory-limit` ;
  - `com.apple.developer.kernel.extended-virtual-addressing` ;
  nécessaires pour charger des modèles LLM volumineux en mémoire.
- `ios/Runner.xcodeproj/project.pbxproj` : le fichier d'entitlements est
  référencé (`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`) pour les
  trois configurations Debug/Profile/Release — **aucune étape Xcode manuelle
  n'est requise** pour les entitlements.

### Étapes manuelles

- Signer avec un profil de provisioning dont l'App ID a les deux capabilities
  mémoire ci-dessus (Xcode « Automatically manage signing » les ajoute seul).
- Debug de gros modèles sur device : ajouter au besoin
  `com.apple.developer.kernel.increased-debugging-memory-limit` (non commité,
  utile uniquement en debug).
- Rappel : iOS Simulator = CPU-only pour l'inférence ; l'audio multimodal
  gemma ne fonctionne que sur device physique.

---

## macOS

### Déjà appliqué

- `macos/Podfile` : `platform :osx, '10.15'` (déjà présent) + le bloc
  `post_install` **verbatim du README flutter_gemma (section « macOS Setup »)** :
  il enveloppe les 3 dylibs d'accélération Apple
  (`GemmaModelConstraintProvider`, `LiteRtMetalAccelerator`,
  `LiteRtTopKMetalSampler`) en bundles `.framework` dans
  `Contents/Frameworks/` et re-pointe le `LC_LOAD_DYLIB` de `LiteRtLm.dylib`.
  Ne pas simplifier ce script (sentinel output = évite le « Cycle inside
  Flutter Assemble » ; phase limitée à la target Runner).
- `macos/Runner/DebugProfile.entitlements` **et** `Release.entitlements` :
  - `com.apple.security.device.audio-input` (micro, dictée) ;
  - `com.apple.security.network.client` (git sync + téléchargement modèles —
    sans lui le sandbox bloque tout réseau sortant) ;
  - `com.apple.security.files.user-selected.read-only` (sélecteur de
    fichiers : imports d'images et d'audio, en lecture seule — le vault vit
    dans le conteneur applicatif et ne nécessite aucun entitlement
    « user-selected » ; aucune fonctionnalité n'écrit dans un fichier choisi
    par l'utilisateur) ;
  - `com.apple.security.cs.disable-library-validation` (chargement des dylibs
    flutter_gemma non signées par le même team ID).
  Les clés d'origine (`app-sandbox`, `allow-jit` + `network.server` en debug)
  sont conservées.
- `macos/Runner/Info.plist` : `NSMicrophoneUsageDescription`.
- `macos/Runner/MainFlutterWindow.swift` : **OCR natif Apple Vision** via
  method channel :
  - channel : `fr.benoitfontaine.second_brain/ocr` ;
  - méthode : `recognize`, arguments `{path: String, languages: [String]?}`
    (défaut `["fr-FR", "en-US"]`) ;
  - `VNRecognizeTextRequest` en `.accurate`, `usesLanguageCorrection`,
    `recognitionLanguages`, auto-détection de langue sur macOS 13+ ;
  - retour : `String` (une ligne par observation, topCandidates(1)) ;
  - erreurs : `FlutterError(code: "BAD_ARGS" | "OCR_FAILED")` — le datasource
    Dart doit les convertir en `OcrException`.

### Étapes manuelles

- Aucune dans Xcode. Après `flutter pub get`, le premier build lance
  `pod install` qui installe la phase de script flutter_gemma.
- Si le script échoue avec « macOS companion dylibs not found » :
  `flutter clean && flutter pub get` (re-télécharge le cache Native Assets).
- Rappel : IA locale **Apple Silicon uniquement** (GPU Metal). macOS Intel =
  mode dégradé sans IA.

---

## Windows

### Déjà appliqué

- Rien à modifier dans `windows/` : flutter_gemma télécharge ses natives
  (LiteRtLm.dll + runtime DXC) au premier build via le hook Native Assets
  (SHA256-vérifié, réseau requis au premier build). GPU via DirectX 12.

### Étapes manuelles (machine de build)

- Windows 10+ **x64 uniquement** (pas de support arm64 pour l'IA locale).
- Visual Studio 2022 avec le workload « Desktop development with C++ ».

### Étapes manuelles (machine utilisateur)

- **MSVC++ Redistributable 2019+** (requis par les DLL LiteRT-LM).
- **OCR** : installer tesseract via l'installeur UB-Mannheim
  (https://github.com/UB-Mannheim/tesseract/wiki) en cochant les données de
  langue *French* ; s'assurer que `tesseract.exe` est dans le `PATH`
  (l'app détecte `tesseract --version` et affiche un message d'installation
  in-app sinon).
- OpenSSL : les DLL nécessaires à git2dart sont fournies par
  `git2dart_binaries` ; en cas d'erreur de chargement, installer les DLL
  OpenSSL x64 (cf. README git2dart).
- Micro : pas de permission manifeste — l'accès est régi par
  Paramètres Windows > Confidentialité > Microphone.

---

## Linux

### Déjà appliqué

- Rien à modifier : `linux/CMakeLists.txt` généré par Flutter copie déjà les
  Native Assets (`native_assets/linux/`) dans le bundle — requis par
  flutter_gemma, ne pas supprimer ce bloc.

### Étapes manuelles (machine de build)

```bash
sudo apt install clang cmake ninja-build libgtk-3-dev lld libssl-dev libpcre3
```

(`libssl-dev`/`libpcre3` : git2dart ; le reste : toolchain Flutter Linux +
flutter_gemma.)

### Étapes manuelles (machine utilisateur, deps runtime)

```bash
sudo apt install pulseaudio-utils tesseract-ocr tesseract-ocr-fra tesseract-ocr-eng libssl3
```

- **pulseaudio-utils** (`parecord`/`pactl`) : requis par `record` pour la
  capture micro — fonctionne aussi sous PipeWire via `pipewire-pulse`.
- **tesseract-ocr + tesseract-ocr-fra** : OCR (CLI appelé par l'app ; message
  d'installation in-app si absent). Fedora : `tesseract tesseract-langpack-fra`.
- **Driver Vulkan vendeur** (NVIDIA/AMD/Intel) pour l'inférence GPU — Mesa
  llvmpipe ne suffit pas (cap `maxStorageBufferRange` 128 Mo) ; sans driver,
  l'inférence retombe sur CPU.
- **libssl** : runtime git2dart (HTTPS).

---

## Rappels transverses (implémentation Dart, hors scope de ce fichier)

- `main()` doit appeler, avant `runApp` : `PlatformSpecific.initialize()`
  (git2dart), `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()], …)`,
  `sherpa_onnx.initBindings()`.
- Modèles téléchargés au premier lancement dans le répertoire de support
  applicatif (jamais dans Documents — corruption mmap iCloud/OneDrive).
- Token git (PAT) dans `flutter_secure_storage`, jamais dans `.git/config`.
