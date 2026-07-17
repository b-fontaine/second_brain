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
    capture/                    # semis multi-format : intake (détection, extraction,
                                # enrichissement), aperçu avant semis, dictée, pépinière
    assistant/                  # IA locale : service LLM, drafts zettel, chat RAG
    explorer/                   # surface fusionnée « jardin » (route /) : constellation,
                                # recherche, pills, sheet persistant — compose graph + zettel
    graph/                      # moteur graphe : simulation force-directed, painter,
                                # cubit (sélection, recherche, LOD, canopées), panneau lecture
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

## Flux de capture : semis → pépinière → repiquage

```
source (dictée | presse-papiers | fichier .md/.txt/image/audio | dépôt fenêtre desktop)
  → CaptureIntake.analyze (domain capture, point d'entrée unique)
      détection du type (extension / contenu du presse-papiers)
      → extraction (texte brut | OCR | transcription)
      → enrichissement IA locale : titre + parcelles proposés
        (repli jamais bloquant : première ligne comme titre)
  → aperçu avant semis (SeedPreviewPage : texte, titre, parcelles éditables)
      — la dictée sème directement à l'arrêt, sans aperçu
  → CaptureIntake.sow : UN item d'inbox enrichi persisté (rien ne se perd)
  → Pépinière (/pepiniere, compteur pill « n semis » sur l'Explorer) :
      Repiquer  → TransplantSeedling : zettel créé avec la provenance
                  capture:<type>:<ref>, item marqué processed
      Modifier  → ZettelEditPage préremplie ; la sauvegarde repique
                  avec les modifications
      Composter → suppression définitive (confirmation)
  → zettel écrit dans le vault → commit git → push si en ligne
```

Le flux assistant historique (découpe LLM en notes atomiques, drafts à
accepter) reste disponible depuis le sélecteur de sources du flux
`CaptureBloc` ; le semis n'y fait plus appel : le découpage se décide au
repiquage, dans la pépinière.

## Flux de requête (RAG local) et assistant sourcé

```
question (texte | voix→STT)
  → recherche hybride dans l'index du vault (mots-clés + similarité)
  → top-k zettels injectés en contexte du LLM local
  → AssistantAnswer{text, sources, related}
      sources = notes réellement citées [[id]] dans la réponse
                (repli : tout le contexte si aucune citation)
      related = notes récupérées mais non citées (« Et peut-être »)
  → chips « Sources » titrées + pastille de maturité → /note/:id
  → « Semer cette synthèse » : la réponse redevient un brouillon de la
    pépinière (CaptureIntake, source « Assistant »)
```

Le degré (pastille de maturité des chips) est résolu par un unique
`getAllZettels` par réponse, avec les mêmes règles d'arêtes que l'Explorer ;
un coffre illisible masque simplement la pastille.

## Note carrefour (lecture & édition)

- **Lecture** (`ZettelReadingView`, partagée entre `/note/:id` et le panneau
  latéral de l'Explorer) : mini-constellation 1-hop **statique**
  (`ZettelMiniConstellation`, aucune animation), corps markdown Literata,
  section « Racines — liens de la note » (entrants/sortants, pastilles de
  maturité), section « Pollinisation — notes proches » (suggestions de
  l'index RAG local, score « Proximité N % » sur la voie sémantique, rang
  sinon) avec action « Tisser » : append `[[id|titre]]` + save + reload.
- **Édition** (`ZettelEditPage`) : coloration markdown légère
  (`MarkdownHighlightingController`), parcelles éditables, bandeau fleur
  « X semble proche — tisser ? » pendant la frappe (debounce public
  `pollinationDebounce` 800 ms, silencieux en échec, désactivable pour la
  session).
- Le moteur de suggestion est unique pour toutes les surfaces :
  `SuggestDraftLinks` (texte libre) et `SuggestRelatedNotes` (autour d'une
  note), adossés à `VaultRagIndex.topKScored` (feature graph, exception
  cross-feature documentée).

## Synchronisation git

- Chaque sauvegarde de note ⇒ commit local immédiat (message conventionnel :
  `note: <titre> (<id>)`).
- Si réseau disponible ⇒ push immédiat ; sinon file d'attente.
- Watcher de connectivité ⇒ au retour du réseau : pull --rebase puis push.
- Conflits : stratégie « le local gagne, copie de sauvegarde du distant »
  (copies sous `conflicts/`), jamais de perte de données.
  `SyncStatus.conflictCount` porte le nombre de conflits résolus par le
  dernier pull (remis à zéro par un pull propre).

### États sync globaux (shell)

- `SyncShellScope` (posé par le router au-dessus d'`AdaptiveScaffold`)
  fournit UN `SyncStatusCubit` partagé à toute la coquille : l'indicateur
  d'AppBar, la pill « À jour / hors ligne » de l'Explorer et la pastille du
  rail le réutilisent (repli getIt hors shell) — une seule souscription au
  statut.
- **Bannière hors-ligne** (`SyncOfflineBanner`, statique) : « n note(s)
  attendent la pluie — synchronisation à la reconnexion » quand des commits
  locaux attendent le réseau.
- **Toast conflit** pédagogique sur front montant 0→n du compteur : « la
  copie distante est conservée dans conflicts/ — vos notes n'ont rien
  perdu » ; la carte ambre des réglages reprend le même message.
- **Anti-doublon** : la pastille `SyncStatusDot` n'apparaît que dans le rail
  étendu (≥ 840 dp) ; en compact, la pill sync de l'Explorer reste le seul
  indicateur près de la barre de recherche.

## UI responsive/adaptive

- Navigation « 2 + 1 » (plan Serre) : Assistant à gauche, Explorer à droite,
  bouton central « Semer » (speed-dial de capture). Barre inférieure en
  compact, navigation rail + FAB Semer ≥ 840 dp.
- Breakpoints Material 3 : compact < 600, medium < 840, expanded ≥ 840.

## Surface Explorer (fusion chantier 2)

`ExplorerPage` (feature `explorer`) est la fusion de la liste de notes et
de la constellation : elle compose les blocs exposés par `zettel`
(`NotesListBloc`) et `graph` (`GraphCubit`) — exception cross-feature
documentée dans le code.

- **Cinq états** : vide (pousse peinte + CTA « Semer »), amas
  (constellation + sheet en peek), sélection (anneau corail + résumé dans
  le peek, panneau droit 400 dp en expanded), recherche (résultats
  flottants sous la barre, nœuds correspondants allumés, reste estompé),
  liste (sheet tiré = liste chronologique groupée par mois, pastilles de
  maturité).
- **Moteur graphe étendu** (feature `graph`, consommé par l'Explorer) :
  couleurs de nœuds par maturité (`SerreTokens`, palette résolue hors
  paint), zoom sémantique `GraphLod` (canopées par tag dominant < 0.35,
  labels des hubs jusqu'à 0.7, tous les labels au-delà), mode recherche
  (`highlightedIds`), suggestions IA « fleurs » (`SuggestRelatedNotes`
  sur l'index RAG local, halo corail). Un seul `CustomPaint` ; le cubit
  précalcule les canopées par révision et n'émet le LOD qu'au
  franchissement d'un seuil.
- **Réactivité** : le graphe et la liste se rafraîchissent sur
  `ZettelRepository.watchVault()` ; le compteur « n semis » écoute
  `VaultWriteNotifier.changes` (`SeedlingCountCubit`) et pousse la
  Pépinière (`/pepiniere`) au tap.

## IA locale

- Interface abstraite `LocalAiService` (domain de `assistant`) :
  `generate`, `generateStream`, `isModelReady`, `downloadModel(progress)`.
- Implémentation principale : `flutter_gemma`.
- La sélection d'implémentation par plateforme est faite dans la couche DI
  (voir docs/RESEARCH.md pour les fallbacks desktop).
- Le modèle est téléchargé au premier lancement (écran des modèles) ou plus
  tard depuis « Réglages → Modèles », jamais embarqué dans le binaire.

## Onboarding & modèles locaux

- **Setup** (`/setup`) : deux cartes — « Nouveau jardin » (coffre local
  immédiat) et « Reprendre un dépôt git » (clone URL + jeton, conservé dans
  le trousseau système, jamais affiché ni loggé). Les échecs s'affichent
  inline dans la carte distante ; la connexion est vérifiée pendant le
  clonage.
- **Écran modèles** (`ModelsInstallView`, dernier pas d'onboarding et route
  `/models`) : une carte par modèle (Reconnaissance vocale, Assistant local)
  avec progression **déterminée** ; `ModelsInstallCubit` est un singleton
  applicatif — « Continuer en arrière-plan » quitte l'écran sans
  interrompre les téléchargements, « Plus tard » reporte tout (l'app
  fonctionne sans modèle, en mode dégradé sans dictée ni assistant).
