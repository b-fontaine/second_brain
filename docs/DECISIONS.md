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
| capture | `SeedPreviewPage` (« aperçu avant semis », poussée par les chips Coller/Fichier et le drop desktop) | aucune route (push impératif au-dessus du shell) |
| capture | `PepinierePage` (« Pépinière — brouillons à valider ») | `/pepiniere` (pill « n semis » de l'Explorer) |
| zettel | `ZettelEditPage` en mode brouillon (préremplie, la sauvegarde repique) | `/pepiniere/edit` (`InboxItem` en `extra`, sinon redirect `/pepiniere`) |
| assistant | `AssistantChatPage` | `/chat` |
| sync | `SettingsPage` | `/settings` (engrenage : bas du rail desktop, barre de recherche Explorer mobile) |
| setup | `ModelsPage` (réutilise `ModelsInstallView`, partagé avec la fin d'onboarding) | `/models` (« Réglages → Modèles ») |

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

## Semer multi-format + Pépinière (chantier 3, plan Serre)

- **`CaptureIntake`** (`lib/features/capture/domain/services/capture_intake.dart`) :
  point d'entrée unique du semis. Payloads scellés (`ClipboardPayload` /
  `FilePayload` / `TextPayload`), détection du type par extension ou contenu
  du presse-papiers (`SeedKind` text|image|audio), réutilisation des
  pipelines existants (`RecognizeScreenshot` pour l'image,
  `TranscribeAudioFile` pour l'audio, lecture **synchrone** des `.md`/`.txt`
  — l'IO async ne complète pas sous FakeAsync), enrichissement titre +
  parcelles via `LocalAiService.generate` (prompt système JSON strict FR
  `{"title","tags"}`) avec **repli jamais bloquant** (première ligne comme
  titre, zéro parcelle). `sow()` = **une seule** écriture inbox enrichie,
  donc une seule pulse `VaultWriteNotifier`/commit sync par semis.
- **Parcours** : Coller et Ajouter un fichier ouvrent `SeedPreviewPage`
  (« aperçu avant semis » : chip du type détecté, texte extrait éditable,
  titre proposé éditable, parcelles supprimables, CTA « Semer en
  pépinière ») ; la dictée (vue immersive « serre de nuit », committée sur
  `SerreTokens.dark`) sème **directement** à l'arrêt
  (`CaptureBloc` → `CaptureSowing` → `CaptureSown`, garde anti-course sur
  `CaptureReset`). Le flux assistant historique (découpage en drafts
  atomiques) reste joignable via « Annuler » depuis la dictée
  (`CaptureIdle` → `CaptureSourcesView`) et couvert par les tests unitaires.
- **`InboxItem` étendu** : `title?` + `tags` (+ `CaptureType.file` pour les
  fichiers texte importés), sérialisation `InboxItemModel` rétrocompatible
  (champs absents/malformés tolérés). Getters mutualisés `proposedTitle`
  (repli première ligne) et `captureSource` (`capture:<type>:<ref>`),
  source de vérité de tout repiquage.
- **Pépinière** (`/pepiniere`, hors shell) : une carte ambre (état
  d'attente) par capture pending — source + horodatage `dd/MM/yyyy · HH:mm`
  (sans `intl`, déterministe en test), titre proposé, extrait 3 lignes,
  chips parcelles. Actions : **Repiquer** = `TransplantSeedling` (placé
  dans `zettel/domain` et non `capture` pour éviter le cycle
  zettel→capture : `CreateZettel` + provenance + marquage processed
  best-effort), **Modifier** = `ZettelEditPage` préremplie via
  `/pepiniere/edit` (la sauvegarde repique avec les modifications, jamais
  `CreateZettel` nu), **Composter** = `removeItem` après confirmation.
  `PepiniereCubit` : `busyItemId` anti double-tap, notices séquencées,
  reload sur chaque pulse `VaultWriteNotifier` (même contrat que la pill
  « n semis » de l'Explorer, `SeedlingCountCubit`).
- **`desktop_drop ^0.7.1` retenu** (brief de recherche : aucun blocage, le
  repli « bouton Fichier seul » n'a pas été nécessaire) : `WindowDropZone`
  enveloppe le body de l'`AdaptiveScaffold` en largeur ≥ 840 dp avec gate
  `isDesktopPlatform` (jamais construit sur mobile/tablette, support
  Android en préversion), dossiers ignorés, premier fichier supporté →
  `seedByDroppedFile` → même aperçu que « Ajouter un fichier » ;
  entitlement macOS `user-selected.read-only` déjà présent.
- **BDD réécrit** : `capture_clipboard/audio/screenshot/dictation.feature`
  couvrent le parcours dial → aperçu → « Semer en pépinière » → vérification
  en pépinière ; `pepiniere.feature` couvre liste, repiquage (note +
  provenance), compostage, pill « n semis » (navigation + mise à jour) et
  état vide. Les steps du flux drafts legacy ont été supprimés (couverture
  conservée par `capture_bloc_test`).

## Note carrefour (chantier 4, plan Serre)

- **Lecture** (`ZettelReadingView`) : mini-constellation 1-hop **statique** en
  tête (`ZettelMiniConstellation` : centre + voisins en cercle déterministe,
  arêtes droites, couleurs `ZettelMaturity` via `GraphPalette`, hauteur bornée
  140, masquée sans lien, zéro animation — la grosse simulation reste à
  l'Explorer) ; corps markdown en Literata ; section **« Racines — liens de la
  note »** (entrants ← / sortants →, pastille de maturité par degré, tap →
  détail) ; section **« Pollinisation — notes proches »** avec action
  **Tisser** = append `[[id|titre]]` en fin de corps (le format du coffre n'a
  pas de section références dédiée) + save + reload.
- **Score affiché** : `VaultRagIndex.topKScored` expose le score — cosine
  normalisé 0..1 côté sémantique (« Proximité N % »), null côté mots-clés
  (« Suggestion n° rang », les scores TF n'étant pas comparables entre
  requêtes). La signature de `topK` est préservée (délégation).
- **Use cases suggestion** : `SuggestDraftLinks` (texte libre → suggestions
  titrées, notes mortes filtrées à la résolution du titre) ;
  `SuggestRelatedNotes` recomposé dessus, renvoie
  `List<RelatedNoteSuggestion>` (id + titre résolu + score). Un seul
  `getAllZettels` par chargement résout titres sortants + carte des degrés
  (mêmes règles d'arêtes que l'Explorer : non orienté, réciproques
  fusionnés, self-links et cibles mortes ignorés).
- **Édition** (`ZettelEditPage`) : coloration markdown légère
  (`MarkdownHighlightingController`, regex combinée en une passe : titres
  `#`, `**gras**`, `[[wikilink]]` teintés accent) ; bandeau fleur « X semble
  proche — tisser ? » pendant la frappe — debounce public
  `ZettelEditPage.pollinationDebounce = 800 ms` (les tests le pompent
  explicitement), requête anti-périmée, échec RAG silencieux, croix qui
  désactive pour la session, Tisser insère au curseur.

## Assistant sourcé (chantier 5, plan Serre)

- **Domaine** : `AssistantSource{id, title, linkCount?}` +
  `AssistantAnswer{text, sources, related}`. `sources` = notes **réellement
  citées** `[[id]]` dans la réponse, dans l'ordre d'apparition (repli = tout
  le contexte récupéré si le modèle ne cite rien — les chips ne disparaissent
  jamais) ; `related` = récupérées non citées (« Et peut-être — notes proches
  non citées »). Titres et degré non orienté résolus par un unique
  `getAllZettels` par réponse ; degré null (coffre illisible) → icône
  document à la place de la pastille.
- **UI** : chips « Sources » titrées avec pastille `ZettelMaturity` → push
  `/note/:id` ; bouton **« Semer cette synthèse »** sur chaque réponse →
  `SowSynthesisCubit` réutilise `CaptureIntake.analyze/sow`
  (`TextPayload(source: CaptureType.assistant)`) — SnackBar « Semé en
  pépinière — brouillon à valider. » ; la Pépinière affiche la source
  « Assistant ». Bulles restylées : utilisateur vert `arbre`, IA carte ivoire
  `surface` + bordure `line` ; hint « Demander au jardin… ».
- **`CaptureType.assistant`** ajouté (3 switches exhaustifs mis à jour) ;
  pas de compat descendante : un binaire antérieur ne relit pas un inbox
  JSON `type=assistant`.

## Entretien (chantier 6, plan Serre)

- **Setup 2 cartes** : « Nouveau jardin » (coffre local) et « Reprendre un
  dépôt git » (URL + jeton en trousseau). Vérification = flux `SetupBloc`
  existant affiché **inline** : « URL de dépôt invalide » en `errorText` du
  champ URL, autres échecs (jeton refusé, clone) sous le champ jeton. Limite
  assumée : pas de vrai test distant avant clonage
  (`testRemoteConnection` exige un dépôt déjà cloné) — mention « la
  connexion est vérifiée pendant le clonage ».
- **Écran modèles** (`ModelsInstallView`, onboarding + `/models`) :
  `ModelsInstallCubit` **@lazySingleton** (les téléchargements survivent à la
  navigation — « Continuer en arrière-plan ») ; états par modèle
  checking/notInstalled/downloading/ready/failed/unsupported, progression
  **déterminée** (jamais d'indicateur indéterminé permanent). Limite
  assumée : `SttModelStore.install()` n'expose qu'un flux global pour ses
  2 paquets sherpa → une seule carte « Reconnaissance vocale ».
  `ModelDownloadStep` supprimé ; libellé « Modèles locaux (optionnels) ».
- **Réglages en cartes** : Synchronisation (résumé + statut + Forcer), Jeton
  d'accès, Jardin (chemin du coffre + « N notes »), Modèles (→ `/models`),
  plus **carte conflit ambre** quand `SyncStatus.conflictCount > 0`.
- **Sync & conflits** : `SyncStatus.conflictCount/hasConflicts` ;
  `GitSyncRepositoryImpl` consomme `pullResult.resolvedConflicts` (remplacé
  à chaque pull, remis à zéro par un pull propre). Sémantique : conflits
  résolus **local gagne** par le dernier pull, copies distantes sous
  `conflicts/`.
- **États sync globaux (shell)** : `SyncShellScope` (au niveau du router,
  au-dessus d'`AdaptiveScaffold`) fournit UN `SyncStatusCubit` partagé
  (indicator AppBar, pill Explorer, pastille rail — repli getIt hors shell)
  + toast pédagogique de conflit sur front montant 0→n ;
  `SyncOfflineBanner` statique (« n note(s) attendent la pluie —
  synchronisation à la reconnexion » quand pendingPush hors ligne) ;
  `SyncStatusDot` ambre/verte **uniquement** dans le rail étendu (≥ 840 dp)
  — côté compact la pill sync de l'Explorer reste le seul indicateur près de
  la recherche (anti-doublon).

## Config plateformes (cumul des briefs)

- Android : minSdk 24, `abiFilters 'arm64-v8a'`, permissions RECORD_AUDIO, INTERNET, POST_NOTIFICATIONS, FOREGROUND_SERVICE_DATA_SYNC + service dataSync (téléchargements gemma), uses-native-library OpenCL (GPU).
- iOS : Podfile `platform :ios, '16.0'`, `use_frameworks! :linkage => :static`. Info.plist : NSMicrophoneUsageDescription, NSPhotoLibraryUsageDescription, UIFileSharingEnabled. Entitlements mémoire (increased-memory-limit, extended-virtual-addressing).
- macOS (Apple Silicon) : post_install flutter_gemma dans Podfile (README du package). Entitlements Debug+Release : audio-input, network.client, user-selected.read-only, disable-library-validation. Info.plist : NSMicrophoneUsageDescription.
- Windows : x64. VS C++/WinRT (platform_ocr). Rien d'autre.
- Linux : x64/arm64. Runtime : PulseAudio (record), tesseract-ocr-fra (OCR), Vulkan vendeur (GPU gemma).
- Limites archi : pas de macOS Intel ni Windows arm64 pour l'IA locale (erreur typée → mode dégradé sans IA).
