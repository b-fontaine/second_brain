# Second Brain

Application de prise de notes **Zettelkasten** assistée par une **IA 100 % locale**.
Offline-first, synchronisée par **git**, multiplateforme : iOS, Android, Windows, Linux, macOS.

## Fonctionnalités

- **Notes atomiques (Zettelkasten)** : une idée = une note markdown, identifiée par un
  horodatage (`yyyyMMddHHmmss`), reliée aux autres par des liens `[[id]]`. Les backlinks
  sont calculés automatiquement, jamais stockés.
- **Inbox de capture** : presse-papiers, captures d'écran (OCR), fichiers audio
  (transcription) et dictée vocale — tout arrive d'abord dans l'inbox, rien ne se perd.
- **Assistant IA local** : découpe les captures en notes atomiques, propose titres, tags
  et liens vers les zettels existants. Les brouillons sont toujours validés par
  l'utilisateur avant d'entrer dans le vault.
- **Chat RAG local** : posez une question, l'app recherche dans votre vault
  (mots-clés + similarité vectorielle) et répond avec des citations `[[id]]` cliquables.
- **Vue graphe** : graphe force-directed de vos notes avec panneau de lecture.
- **Synchronisation git** : chaque sauvegarde = commit local immédiat ; push/pull
  opportuniste dès que le réseau est disponible. Les conflits ne perdent jamais de
  données (le local gagne, copie de sauvegarde du distant).
- **Vie privée** : aucune donnée ne quitte l'appareil. LLM, embeddings, STT et OCR
  tournent entièrement en local.

## La méthode Zettelkasten

Le vault est un simple dossier de fichiers markdown, compatible Obsidian/Zettlr :

```
vault/
  zettel/   # notes permanentes (archive plate)
  inbox/    # captures brutes à traiter
  assets/   # images / audio importés
```

Chaque note : `<id>-<slug-du-titre>.md` avec un frontmatter YAML (`id`, `title`,
`date`, `tags`, `source` optionnel), des liens `[[20260714103000|texte affiché]]`
rédigés en contexte, et une section `## Références` pour les sources externes.

## Stack technique

| Domaine | Technologie |
|---|---|
| Framework | Flutter (Material 3, responsive mobile → desktop) |
| Architecture | Clean Architecture par feature + TDD/BDD (Gherkin) |
| State management | flutter_bloc |
| Injection de dépendances | get_it + injectable (build_runner) |
| Erreurs fonctionnelles | fpdart (`Either<Failure, T>`) |
| IA locale (LLM) | flutter_gemma + LiteRT-LM (modèle par défaut : Qwen3 0.6B) |
| RAG | flutter_gemma_embeddings + flutter_gemma_rag_sqlite |
| Git embarqué | git2dart (libgit2 FFI, aucun git système requis) |
| Reconnaissance vocale | sherpa_onnx (zipformer streaming FR + Whisper) + record |
| OCR | ML Kit (mobile), Apple Vision (macOS), tesseract CLI (Windows/Linux) |
| Markdown | front_matter_ml, markdown, flutter_markdown_plus |
| Navigation | go_router |
| Tests | flutter_test, bloc_test, mocktail, bdd_widget_test |

## Prérequis par plateforme

Détail complet (permissions, entitlements, étapes Xcode) : [docs/PLATFORM_SETUP.md](docs/PLATFORM_SETUP.md).

| Plateforme | Minimum | Prérequis build | Prérequis runtime |
|---|---|---|---|
| Android | API 24, **arm64-v8a uniquement** | SDK Android, NDK | — |
| iOS | iOS 16.0 | Xcode 15.3+, CocoaPods | — |
| macOS | macOS 10.15, **Apple Silicon uniquement** pour l'IA | Xcode, CocoaPods | — |
| Windows | Windows 10 **x64 uniquement** | VS 2022 « Desktop development with C++ » | MSVC++ Redistributable 2019+, tesseract (OCR) |
| Linux | x64 / arm64 | `clang cmake ninja-build libgtk-3-dev lld`, `libssl-dev` | `pulseaudio-utils`, `tesseract-ocr` + `tesseract-ocr-fra`, driver Vulkan vendeur, libssl |

Limites d'architecture : **pas d'IA locale** sur macOS Intel ni Windows arm64
(l'app fonctionne en mode dégradé sans assistant).

## Démarrage

```bash
flutter pub get

# Génération DI (injectable) + steps BDD
dart run build_runner build --delete-conflicting-outputs

# Lancer (choisir le device)
flutter run
```

Sur iOS/macOS, la première compilation exécute `pod install` automatiquement.
Le premier build télécharge aussi les bibliothèques natives LiteRT-LM
(Native Assets, vérifiées par SHA256) — une connexion réseau est nécessaire.

## Modèles téléchargés au premier lancement

Aucun modèle n'est embarqué dans le binaire. Au premier lancement, l'écran de
configuration télécharge (avec barre de progression) :

| Modèle | Usage | Taille | Accès |
|---|---|---|---|
| Qwen3 0.6B (.litertlm) | LLM par défaut | ~586 Mo | public |
| Gemma 3 1B / Gemma3n E2B (option) | LLM | 0,5–3,1 Go | token Hugging Face requis (repos gated) |
| EmbeddingGemma / Gecko | embeddings RAG | 110–179 Mo | gated / public |
| zipformer streaming FR (int8) | dictée | ~130 Mo | public |
| Whisper small (int8) | transcription fichiers | ~250 Mo | public |

Les modèles sont stockés hors du dossier Documents (pour éviter la corruption
mmap par iCloud/OneDrive), dans le répertoire de support applicatif.

## Tests

```bash
# Tous les tests (unitaires, blocs, widgets BDD)
flutter test

# Régénérer les step definitions à partir des .feature Gherkin
dart run build_runner build --delete-conflicting-outputs
```

Les specs BDD vivent dans `test/features/*.feature` ; `bdd_widget_test` génère
les tests correspondants via build_runner. Les tests unitaires suivent le
miroir de `lib/` dans `test/`.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — architecture, format du vault, flux de capture et RAG
- [docs/DECISIONS.md](docs/DECISIONS.md) — décisions techniques et contrats de domaine
- [docs/PLATFORM_SETUP.md](docs/PLATFORM_SETUP.md) — configuration native détaillée par plateforme
- [docs/research/](docs/research/) — briefs de recherche packages (API vérifiées)
