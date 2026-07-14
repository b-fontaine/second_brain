# Second Brain — Architecture

Application Flutter de prise de notes Zettelkasten assistée par IA locale.
Cibles : iOS, Android, Windows, Linux, macOS. Offline-first, synchronisation git.

## Principes

- **Clean Architecture** stricte par feature : `domain` (entités, repositories abstraits,
  use cases) → `data` (datasources, models, implémentations) → `presentation` (blocs, pages, widgets).
- **TDD/BDD** : specs Gherkin dans `test/features/*.feature` (générées via `bdd_widget_test`),
  tests unitaires par use case et bloc.
- **State management** : `flutter_bloc`. Un bloc/cubit par écran ou flux.
- **DI** : `get_it` + `injectable` (génération via `build_runner`). Toutes les dépendances
  injectées par constructeur ; jamais de singleton accédé directement dans le domaine.
- **Erreurs** : les use cases retournent `Either<Failure, T>` (fpdart). Les datasources
  lèvent des `Exception` typées converties en `Failure` par les repositories.
- **Offline-first** : le vault local (dossier de fichiers markdown) est la source de vérité.
  La synchronisation git est opportuniste et ne bloque jamais l'UI.

## Structure

```
lib/
  main.dart                     # bootstrap : DI, runApp
  app.dart                      # MaterialApp.router, thème, localisation
  core/
    di/                         # injection.dart + injection.config.dart (généré)
    error/                      # failures.dart, exceptions.dart
    usecases/                   # UseCase<T, Params> abstrait
    router/                     # navigation (go_router), routes nommées
    theme/                      # thème Material 3, responsive breakpoints
    services/                   # abstractions transverses (clock, uuid, network_info)
    widgets/                    # widgets partagés (adaptive scaffold…)
  features/
    setup/                      # onboarding : config repo git distant ou vault local
    zettel/                     # cœur : entités Zettel, vault markdown, CRUD, liens, inbox
    capture/                    # assistants de capture : clipboard, audio, screenshot, dictée
    assistant/                  # IA locale : service LLM, drafts zettel, chat RAG
    graph/                      # vue graphe force-directed + panneau de lecture
    sync/                       # git : clone/commit/push/pull, statut, auto-sync
test/
  features/                     # *.feature Gherkin (bdd_widget_test)
  step/                         # step definitions générées + custom
  <miroir de lib/>              # tests unitaires
```

Chaque feature suit :

```
features/<nom>/
  domain/entities/  domain/repositories/  domain/usecases/
  data/models/      data/datasources/     data/repositories/
  presentation/bloc/  presentation/pages/  presentation/widgets/
```

## Format Zettel (source de vérité : fichiers markdown)

- Un fichier = une note atomique. Dossier vault :
  - `zettel/` notes permanentes
  - `inbox/` captures brutes à traiter
  - `assets/` images/audio importés
- Nom de fichier : `<id>-<slug-du-titre>.md`, id horodaté `yyyyMMddHHmmss`.
- Frontmatter YAML (compatible Obsidian/Zettlr) :

```yaml
---
id: "20260714103000"
title: Mémoire de travail
date: 2026-07-14T10:30:00+02:00
tags: [cognition, memoire]
source: "capture:audio:meeting.m4a"   # optionnel, provenance
---
```

- Liens : `[[20260714103000]]` ou `[[20260714103000|texte affiché]]` (id cible).
  Les backlinks sont calculés par indexation, jamais stockés.
- Section `## Références` en fin de note pour les sources externes.

## Flux de capture (assistant IA)

```
source (clipboard | fichier audio | image | dictée)
  → extraction (texte brut | STT | OCR)
  → item d'inbox persisté (rien ne se perd)
  → assistant LLM local : découpe en notes atomiques,
    titres, tags, liens suggérés vers zettels existants (similarité)
  → drafts présentés à l'utilisateur (éditer / accepter / rejeter)
  → acceptation → zettels écrits dans le vault → commit git → push si en ligne
```

## Flux de requête (RAG local)

```
question (texte | voix→STT)
  → recherche hybride dans l'index du vault (mots-clés + similarité)
  → top-k zettels injectés en contexte du LLM local
  → réponse avec citations [[id]] cliquables
```

## Synchronisation git

- Chaque sauvegarde de note ⇒ commit local immédiat (message conventionnel :
  `note: <titre> (<id>)`).
- Si réseau disponible ⇒ push immédiat ; sinon file d'attente.
- Watcher de connectivité ⇒ au retour du réseau : pull --rebase puis push.
- Conflits : stratégie « le local gagne, copie de sauvegarde du distant »
  (note dupliquée avec suffixe `-conflict`), jamais de perte de données.

## UI responsive/adaptive

- Mobile d'abord : navigation par barre inférieure (Notes, Capture, Chat, Graphe).
- ≥ 840 dp (desktop/tablette paysage) : navigation rail + layout deux panneaux
  (liste/graphe à gauche, panneau de lecture à droite).
- Breakpoints Material 3 : compact < 600, medium < 840, expanded ≥ 840.

## IA locale

- Interface abstraite `LocalAiService` (domain de `assistant`) :
  `generate`, `generateStream`, `isModelReady`, `downloadModel(progress)`.
- Implémentation principale : `flutter_gemma`.
- La sélection d'implémentation par plateforme est faite dans la couche DI
  (voir docs/RESEARCH.md pour les fallbacks desktop).
- Le modèle est téléchargé au premier lancement (écran de setup, barre de progression),
  jamais embarqué dans le binaire.
