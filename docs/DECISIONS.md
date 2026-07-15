# Décisions techniques (validées par recherche pub.dev du 2026-07-14)

Briefs détaillés dans `docs/research/*.md` — les lire avant d'implémenter la feature concernée.

## Stack

| Domaine | Choix | Détail |
|---|---|---|
| IA locale | `flutter_gemma ^1.2.3` + `flutter_gemma_litertlm ^1.1.0` | Desktop supporté via LiteRT-LM (.litertlm). `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])` obligatoire dans main(). |
| RAG | `flutter_gemma_embeddings ^1.0.2` + `flutter_gemma_rag_sqlite ^1.1.0` | Embeddings + vector store portable 5 plateformes. |
| Modèle LLM défaut | Qwen3 0.6B (586 MB, public, pas de token HF) | Option Gemma 3 1B / Gemma3n E2B avec token HF (repos gated). Téléchargement au premier lancement, jamais embarqué. |
| Git | `git2dart ^0.5.3` | libgit2 FFI, binaires précompilés, 5 plateformes. `PlatformSpecific.initialize()` dans main() AVANT tout appel git. Token PAT dans flutter_secure_storage. |
| STT | `sherpa_onnx ^1.13.4` + `record ^7.1.1` + `permission_handler ^12.0.3` | Dictée : zipformer streaming FR (~130 MB). Fichiers : whisper small int8. Modèles téléchargés dans getApplicationSupportDirectory(). |
| OCR | Par plateforme derrière `OcrService` | Android/iOS : `google_mlkit_text_recognition ^0.16.0`. macOS : method channel Swift Vision (~40 lignes, fr-FR). Windows + Linux : CLI `tesseract` via Process.run (détecter `tesseract --version`, sinon message d'installation in-app). NOTE : `platform_ocr` rejeté — conflit de résolution avec flutter_gemma_rag_sqlite. Normaliser toute image en PNG temporaire avant OCR. |
| Import images | `image_picker ^1.2.3` + `file_selector` + `pasteboard ^0.5.0` | pasteboard = collage image presse-papiers desktop. |
| Graphe | Implémentation maison CustomPainter + simulation d3-force | AUCUN package. Voir brief graph : Barnes-Hut, alpha cooling, phyllotaxis init, un seul CustomPaint + ValueNotifier, PAS d'InteractiveViewer. |
| Markdown | `front_matter_ml ^1.2.0`, `markdown ^7.3.1`, `slugify ^2.0.0`, `flutter_markdown_plus` (rendu) | |
| Tests | `bdd_widget_test ^2.1.4`, `bloc_test ^10.0.0`, `mocktail ^1.0.5` | .feature dans test/features/, steps générés dans test/features/step/. |

## Format vault (spec zettelkasten.de)

- `zettel/` (archive plate), `inbox/`, `assets/`. Fichier : `<id>-<slug>.md`, id `yyyyMMddHHmmss`.
- Frontmatter : `id` (string quotée), `title`, `date` ISO, `tags` liste, `source` optionnel.
- Liens `[[id]]` / `[[id|libellé]]` avec contexte rédigé. Backlinks calculés, jamais stockés.
- Capture → inbox d'abord (rien ne se perd), assistant → drafts → validation utilisateur → zettels.

## Contrats (déjà écrits — NE PAS MODIFIER, implémenter contre)

- `lib/core/` : failures, exceptions, UseCase/StreamUseCase, DI (`@injectable`), NetworkInfo, Clock, AppTheme/Breakpoints.
- `lib/features/zettel/domain/` : Zettel, ZettelId, InboxItem, ZettelRepository, InboxRepository + 7 use cases.
- `lib/features/assistant/domain/` : ZettelDraft, AssistantAnswer, LocalAiService, AssistantRepository.
- `lib/features/capture/domain/services/` : TranscriptionService, OcrService, ClipboardService.
- `lib/features/sync/domain/` : SyncStatus, GitSyncRepository.
- `lib/features/setup/domain/` : VaultConfig, SetupRepository.

## Conventions pages/routes (pour le shell + agents)

> Note « jalon A » (plan Serre, chantier 1) : navigation « 2 + 1 » —
> Assistant à gauche, Explorer à droite, bouton central « Semer » qui ouvre
> le speed-dial (`SeedDial` : Dicter / Coller / Ajouter un fichier, branché
> sur les flux `CaptureBloc` existants). `CapturePage` n'est plus une
> destination : le dial la pousse en plein écran, préamorcée par événement.

| Feature | Page (classe) | Route |
|---|---|---|
| setup | `SetupPage` | `/setup` |
| explorer | `ExplorerPage` (chantier 2 : surface fusionnée liste + constellation, voir section suivante) | `/` |
| zettel | `ZettelDetailPage` | `/note/:id` |
| zettel | `ZettelEditPage` | `/note/:id/edit` et `/new` |
| capture | `CapturePage` (poussée par le `SeedDial`, plus une destination) | `/capture` → redirect `/?semer=1` (ouvre le dial) |
| assistant | `AssistantChatPage` | `/chat` |
| sync | `SettingsPage` | `/settings` (engrenage : bas du rail desktop, barre de recherche Explorer mobile) |

Navigation adaptive : barre basse 2 destinations + bouton Semer central
(compact) / navigation rail + FAB Semer et raccourcis `⌘⇧D`/`⌘⇧V`/`⌘⇧O`
(≥ 840 dp, Ctrl hors macOS), panneau de lecture latéral en expanded.

## Fusion Explorer (chantier 2, plan Serre)

- **Une seule surface** : `ExplorerPage` (route `/`) superpose la
  constellation plein écran (`ExplorerConstellation`, qui réutilise le
  moteur graphe : un seul `CustomPaint`/`GraphPainter`, `ForceSimulation`
  et cache de `TextPainter` partagés), une barre de recherche flottante,
  une rangée de pills (« n semis », statut de synchro) et un
  `DraggableScrollableSheet` persistant en compact (peek 0.10, résumé de
  sélection 0.34, liste chronologique 0.90). En expanded (≥ 840 dp) :
  panneau de lecture droit 400 dp à la sélection, panneau liste gauche
  360 dp togglable, pas de sheet. Cinq états : vide, amas, sélection,
  recherche, liste.
- **Pages supprimées** : `NotesHomePage` (coquille sans référence),
  `NotesBrowser` (remplacé par la surface fusionnée) et `GraphPage`
  (la constellation est désormais l'Explorer). Les redirects `/graph → /`
  et `/capture → /?semer=1` restent pour les liens profonds. Les tests du
  moteur (pinch-zoom, label de sémantique) ont migré vers
  `explorer_page_test.dart`.
- **Couleur = état** : nœuds colorés par maturité (`ZettelMaturity` :
  pousse < 2 liens, feuillage 2–3, arbre ≥ 4) via `SerreTokens` ;
  sélection = anneau corail (`fleur`), suggestions IA = halo corail
  (« fleurs », `SuggestRelatedNotes` sur `VaultRagIndex`, exclusion
  self/voisins, garde anti-réponses périmées).
- **Zoom sémantique (`GraphLod`)** : canopées par tag dominant sous
  `canopyMaxScale = 0.35`, labels des hubs (degré ≥ `hubLabelMinDegree
  = 4`) entre 0.35 et `fullLabelsMinScale = 0.7`, tous les labels
  au-delà. Le cubit n'émet qu'au franchissement d'une bande, jamais par
  frame de pinch ; canopées précalculées par révision, centroïdes O(N)
  au paint.
- **BDD** : `graph_visualization.feature` (gelée au jalon A) réécrite en
  `explorer_constellation.feature` — la constellation n'étant plus une
  destination, il n'y a plus de step « I open the graph view » ; les
  assertions lisent toujours `GraphCubit`/`GraphPainter` via le
  `CustomPaint`.

## Config plateformes (cumul des briefs)

- Android : minSdk 24, `abiFilters 'arm64-v8a'`, permissions RECORD_AUDIO, INTERNET, POST_NOTIFICATIONS, FOREGROUND_SERVICE_DATA_SYNC + service dataSync (téléchargements gemma), uses-native-library OpenCL (GPU).
- iOS : Podfile `platform :ios, '16.0'`, `use_frameworks! :linkage => :static`. Info.plist : NSMicrophoneUsageDescription, NSPhotoLibraryUsageDescription, UIFileSharingEnabled. Entitlements mémoire (increased-memory-limit, extended-virtual-addressing).
- macOS (Apple Silicon) : post_install flutter_gemma dans Podfile (README du package). Entitlements Debug+Release : audio-input, network.client, user-selected.read-only, disable-library-validation. Info.plist : NSMicrophoneUsageDescription.
- Windows : x64. VS C++/WinRT (platform_ocr). Rien d'autre.
- Linux : x64/arm64. Runtime : PulseAudio (record), tesseract-ocr-fra (OCR), Vulkan vendeur (GPU gemma).
- Limites archi : pas de macOS Intel ni Windows arm64 pour l'IA locale (erreur typée → mode dégradé sans IA).
