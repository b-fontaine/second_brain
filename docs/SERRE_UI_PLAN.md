# Plan d'implémentation — Thème « La Serre »

> Maquettes de référence : artifact « La Serre — toutes les surfaces »
> (https://claude.ai/code/artifact/9d7fb29c-8e30-4d31-af47-90fb9b2f26ae, version `iteration-3-serre-ecrans`).
> Ce plan découpe la mise en œuvre en 7 chantiers ordonnés, chacun livrable et
> vérifiable indépendamment (analyze 0 issue, tests verts, build macOS).

## Principes

- **La Serre est une peau plus deux fusions** (Explorer = notes ∪ graphe,
  capture 4 → 3 entrées multi-format). Aucune refonte de la Clean Architecture :
  domain et data ne bougent presque pas, l'essentiel se joue en presentation.
- **La couleur code l'état** : pousse (0–1 lien) `#B7CFA6`, feuillage (2–3)
  `#7FA86B`, arbre (4+) `#2F6B4F`, fleur (suggestion IA) `#E8705F`,
  ambre (attente/conflit) `#C9A44A`.
- **La métaphore n'est jamais seule** : chaque libellé jardinier garde un sens
  fonctionnel explicite (« Pépinière — brouillons à valider »).
- Offline-first inchangé : polices embarquées (pas de google_fonts runtime),
  aucun nouvel appel réseau.

## Chantier 0 — Fondations : tokens, typographie, thème

**Objectif** : rethémer toute l'app sans changer un seul comportement.

- `lib/core/theme/serre_tokens.dart` : `ThemeExtension<SerreTokens>` —
  `paper, surface, line, ink, sub, accent, accentSoft, pousse, feuillage,
  arbre, fleur, ambre, scrim`, variantes light + dark (« serre de nuit »,
  tokens provisoires à affiner en itération design ultérieure).
- Refonte de `AppTheme` ([app_theme.dart](../lib/core/theme/app_theme.dart)) :
  `ColorScheme` construit depuis les tokens (fini le seed indigo `#4C6FFF`),
  cartes radius 14–16, inputs arrondis, SnackBar façon toast sombre `#27331F`.
- Polices embarquées (`assets/fonts/` + pubspec) :
  - **Literata** (variable, OFL) : titres et corps de note (serif humaniste) ;
  - **JetBrains Mono** (OFL) : métadonnées, dates, compteurs ;
  - UI courante : police système (par défaut Flutter).
- `lib/features/zettel/presentation/utils/zettel_maturity.dart` :
  `ZettelMaturity.of(int linkCount)` → enum + couleur via tokens.
  Utilisé partout (graphe, listes, pastilles).
- Tests : unit sur `ZettelMaturity`, smoke test thème (extension présente,
  contrastes non nuls). Les goldens sont optionnels et hors périmètre.

**Dépend de** : rien. **Taille** : S–M.

## Chantier 1 — Navigation « 2 + 1 »

**Objectif** : Assistant à gauche, Explorer à droite, bouton Semer central.

- `AdaptiveScaffold` ([adaptive_scaffold.dart](../lib/core/widgets/adaptive_scaffold.dart)) :
  - **Mobile** : barre à 2 destinations + bouton rond central débordant
    (Stack custom : bouton 60 px, bordure 4 px couleur fond, ombre verte —
    plus fidèle à la maquette que `centerDocked`) ; `SafeArea` pour les
    gestes système Android.
  - **Desktop/large** : rail 2 icônes + engrenage en bas ; FAB Semer
    flottant bas-droite.
- **Speed-dial Semer** : overlay scrim + 3 chips (Dicter / Coller /
  Ajouter un fichier, sous-titres formats). Composant unique
  `lib/features/capture/presentation/widgets/seed_dial.dart` utilisé par les
  deux form factors.
- Raccourcis desktop au niveau shell (`Shortcuts`/`Actions`) :
  `⌘⇧D` dicter, `⌘⇧V` coller, `⌘⇧O` fichier.
- Routage ([app_router.dart](../lib/core/router/app_router.dart)) :
  - `/` → `ExplorerPage` (nouvelle ; au début simple conteneur de
    `NotesHomePage` pour livrer la nav sans attendre le chantier 2) ;
  - `shellTabPaths` 4 → 2 (`/`, `/chat`) ;
  - `/graph` → redirect `/` ; `/capture` → redirect `/` + ouverture du dial
    (query param `?semer=1`) — les deep links restent valides ;
  - `/settings` accessible depuis l'engrenage (barre de recherche mobile,
    bas du rail desktop).
- `CapturePage` n'est plus une destination : le dial appelle directement les
  flux existants (dictée, collage, fichier).

**Dépend de** : 0. **Taille** : M.

## Chantier 2 — Explorer fusionné (le gros morceau)

**Objectif** : une seule surface, cinq états (vide, amas, sélection,
recherche, liste), conforme au parcours 2 des maquettes.

- `lib/features/explorer/presentation/pages/explorer_page.dart` :
  Stack = constellation plein écran + barre de recherche + pills (semis,
  statut sync) + `DraggableScrollableSheet`.
- Extensions moteur graphe (réutiliser `ForceSimulation` + `GraphPainter`,
  un seul CustomPaint, cache TextPainter existant) :
  - couleur des nœuds = `ZettelMaturity` (backlinks déjà calculés) ;
  - nœuds « fleur » = top-K RAG non liés au voisinage affiché (flag) ;
  - **zoom sémantique (LOD)** : échelle < s₁ → canopées (amas par tag
    dominant : centroïde des nœuds, rayon ∝ effectif, étiquette + compte) ;
    s₁–s₂ → nœuds + labels des plus connectés ; > s₂ → tous les labels ;
  - **mode recherche** : `Set<ZettelId>` allumés, le reste estompé.
- États :
  - **vide** : illustration pousse + CTA vers le bouton Semer ;
  - **sélection** : anneau corail + sheet peek (titre, n liens, n proches,
    tags) → tap = détail ;
  - **liste** : sheet remonté = liste chronologique groupée (reprend le
    contenu de `NotesHomePage`, pastilles maturité) ;
  - **recherche** : liste flottante de résultats (SearchZettels) + nœuds
    allumés en parallèle.
- **Desktop** : panneau de lecture latéral (widgets partagés avec le détail),
  pill « n semis », pill « À jour / hors-ligne ».
- Fin de chantier : suppression de `NotesHomePage` et `GraphPage` (les
  redirects de routes restent).

**Dépend de** : 1. **Taille** : L.
**Risque principal** : perf du LOD sur mobile — mesurer à 500+ notes,
profiler le repaint avant d'optimiser.

## Chantier 3 — Semer : capture 3 entrées multi-format + Pépinière

**Objectif** : parcours 4 des maquettes.

- `lib/features/capture/domain/services/capture_intake.dart` : point d'entrée
  unique — payload (texte | image | audio | fichier) → détection de type
  (mime/extension/pasteboard) → pipeline existant (OCR / transcription /
  markdown brut) → brouillon inbox enrichi (source, titre et parcelles
  proposés par `LocalAiService`).
- **Coller** : `pasteboard` (texte + image ; l'audio passe par fichier) →
  écran d'aperçu avant semis : segmented du type détecté, texte OCR
  modifiable, parcelles proposées, CTA « Semer en pépinière ».
- **Fichier** : `file_selector` (déjà en dépendance) multi-extensions
  `.md .txt` / images / audio.
- **Dictée** : restyle immersif (fond serre de nuit, onde d'amplitude depuis
  le stream de `record`, transcript live existant) ; stop → pépinière.
- **Pépinière** (`/pepiniere`) : revue des brouillons inbox — carte par semis
  (source + horodatage, titre proposé, extrait, parcelles), actions
  **Repiquer** (inbox → zettel), **Modifier** (édition préremplie),
  **Composter** (suppression). Compteur → pill Explorer.
- **Desktop** : glisser-déposer sur la fenêtre — évaluer `desktop_drop`
  (brief de recherche avant démarrage : compat macOS/Windows/Linux) ;
  repli : bouton Fichier seul.

**Dépend de** : 1 (dial). Parallélisable avec 2. **Taille** : L.

## Chantier 4 — Note : lecture & édition

**Objectif** : parcours 3 des maquettes — la note comme carrefour.

- **Lecture** (`ZettelDetailPage`) : mini-constellation 1-hop en tête
  (layout statique dédié, pas la grosse simulation), corps serif Literata,
  section **Racines** (entrants ← / sortants →, pastilles maturité),
  section **Pollinisation** (RAG topK moins les déjà-liés, score affiché)
  avec action **Tisser** = append `[[id|titre]]` + save + refresh.
- **Édition** (`ZettelEditPage`) : coloration markdown légère
  (`TextEditingController` custom : `**gras**`, `[[wikilink]]`, `#`),
  parcelles éditables, bandeau fleur « X semble proche — tisser ? » pendant
  la frappe (RAG débounce 800 ms, désactivable ; repli V2 si la latence
  mobile est mauvaise).

**Dépend de** : 0. Parallélisable avec 2/3. **Taille** : M.

## Chantier 5 — Assistant sourcé

- Exposer les documents récupérés par le RAG dans l'état du chat →
  **chips sources** cliquables (push détail) + section « Et peut-être »
  (proches non cités).
- Action « **Semer cette synthèse** » : la réponse devient un brouillon en
  pépinière (réutilise `CaptureIntake` texte).
- Restyle bulles (utilisateur vert `arbre`, IA carte ivoire), champ
  « Demander au jardin… » avec micro (dictée de la question, flux existant).

**Dépend de** : 0, 3 (`CaptureIntake`). **Taille** : S–M.

## Chantier 6 — Entretien : onboarding, réglages, états sync

- **Setup** : deux cartes (Nouveau jardin / Reprendre un dépôt git), jeton en
  trousseau, test de connexion inline (logique `SettingsCubit`/usecases
  existante) ; puis **écran modèles** : progression par modèle
  (stream `SttModelStore.install()` + téléchargement Gemma), bouton
  « Continuer en arrière-plan ».
- **Réglages** : cartes Synchronisation / Jeton / Jardin / Modèles,
  carte conflit ambre (« la copie distante est dans conflicts/ »).
- **Global (shell)** : écoute du statut sync — bannière hors-ligne
  (« n notes attendent la pluie »), toast conflit pédagogique, pastille
  ambre/verte dans la barre de recherche et le rail.

**Dépend de** : 0. **Taille** : M.

## Transversal (à chaque chantier)

- **BDD** : mettre à jour les `.feature` impactés (navigation fusionnée,
  capture 3 entrées, états Explorer, pépinière) + steps régénérés.
  Rappel process : **jamais deux `flutter test` concurrents** dans ce repo.
- **Docs** : tenir à jour `DECISIONS.md` (table des routes, fusions) et
  `ARCHITECTURE.md` (theme, feature explorer).
- **Validation par chantier** : `flutter analyze` 0 issue, suite complète
  verte, build macOS ; commit par chantier sur `main`.

## Ordre et jalons

```
0 Fondations ──► 1 Navigation ──► 2 Explorer (L)
                      │             ∥ (parallélisable)
                      ├──────────► 3 Semer + Pépinière (L)
0 ────────────────────┼──────────► 4 Note (M)
                      └──────────► 5 Assistant (S–M, après 3)
0 ────────────────────────────────► 6 Entretien (M)
```

| Jalon | Contenu | Résultat visible | Statut |
|-------|---------|------------------|--------|
| A | 0 + 1 | App entièrement rethémée, nav 2+1, dial semer branché sur les flux actuels | ✅ Livré |
| B | + 2 | Explorer fusionné (5 états), suppression notes/graph | ✅ Livré |
| C | + 3 | Capture multi-format + pépinière | ✅ Livré |
| D | + 4, 5, 6 | Note-carrefour, assistant sourcé, entretien | ✅ Livré (BDD + docs à jour) |

## Risques identifiés

| Risque | Mitigation |
|--------|------------|
| Perf LOD/canopées sur mobile (500+ notes) | Profiler avant d'optimiser ; LOD réduit d'abord, canopées pré-calculées par tag |
| Poids des polices embarquées | Literata variable + JetBrains Mono ≈ 600 Ko compressés — acceptable |
| Bouton central vs gestes système Android | `SafeArea` + inset bottom testé sur device |
| `desktop_drop` non maintenu / incompatible | Brief de recherche avant chantier 3 ; repli bouton Fichier |
| Deep links `/graph`, `/capture` cassés | Redirects conservés dans le router |
| Latence RAG pendant la frappe (chantier 4) | Debounce 800 ms + flag de désactivation ; repli V2 |
| Mode sombre « serre de nuit » non maquetté | Tokens provisoires au chantier 0, itération design dédiée ensuite |
