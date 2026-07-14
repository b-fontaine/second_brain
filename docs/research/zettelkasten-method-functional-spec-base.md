# Zettelkasten method functional spec (based on zettelkasten.de) for a markdown-file note app, including AI ingestion pipeline

## Recommandation

Plain markdown files + YAML frontmatter. No dedicated Zettelkasten package exists on pub.dev; implement with `front_matter_ml: 1.2.0` (frontmatter parsing) + `yaml: 3.1.3` (YAML), `markdown: 7.3.1` (rendering/AST), `slugify: 2.0.0` (filename slugs). Follow zettelkasten.de conventions: timestamp IDs (YYYYMMDDHHMM), [[ID]] wikilinks with written link context, flat archive + inbox/ folder.

## Support plateformes

{"android": true, "ios": true, "windows": true, "linux": true, "macos": true}

## Fallback

front_matter_ml (1.2.0) was last published ~3 years ago. If it proves stale, hand-roll frontmatter extraction — split on the `---\n...\n---\n` delimiter with a regex and parse the block with package:yaml (snippet in api_notes, ~15 lines, zero extra dependencies). All other conventions in this spec are file-format-level and have no package dependency at all.

## Entrées pubspec

- `front_matter_ml: ^1.2.0`
- `yaml: ^3.1.3`
- `markdown: ^7.3.1`
- `slugify: ^2.0.0`

## Setup plateforme

No platform permissions needed if the vault lives in the app's documents directory (path_provider getApplicationDocumentsDirectory). If the user may pick an external vault folder (recommended for Obsidian interop): macOS — sandbox entitlements `com.apple.security.files.user-selected.read-write` in DebugProfile/Release .entitlements and persist access via security-scoped bookmarks; iOS — use UIDocumentPicker (file_picker/file_selector) and optionally `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` = YES in Info.plist to expose the vault in the Files app; Android — use Storage Access Framework directory picker (persistable URI grants) rather than MANAGE_EXTERNAL_STORAGE, minSdk 21+ is fine; Windows/Linux — plain paths, nothing needed. All four listed packages are pure Dart (no native code), so no further platform config. Verified on pub.dev 2026-07-14: front_matter_ml 1.2.0, yaml 3.1.3, markdown 7.3.1, slugify 2.0.0 — all declare Android/iOS/Windows/Linux/macOS support.

## Notes API

# Zettelkasten Functional Spec (markdown-file note app)

Sources: zettelkasten.de/overview/, zettelkasten.de/introduction/, zettelkasten.de/posts/add-identity/, zettelkasten.de/posts/concepts-sohnke-ahrens-explained/ (fetched 2026-07-14).

## 1. Atomicity & autonomy (core invariants)

- **Atomicity**: one knowledge building block per note. zettelkasten.de: "put things that belong together into a single note, give it an ID, but limit its content to that single topic." It is "a guiding compass, not a rigid law" — the app should encourage, not hard-enforce (e.g. warn when a note grows past ~300–500 words or covers multiple headings, offer "split note" action).
- **Autonomy / self-containment**: every note must be understandable later without the original source or surrounding notes. Written in the user's own words, not pasted quotes. Ahrens: permanent notes are "written as if for print."
- Consequence for the app: a note is the unit of addressing, linking, search, and display. Never merge notes implicitly; splitting is a first-class operation.
- **Knowledge vs information**: information fits in a sentence; knowledge = information + context + relevance. Processing (rewriting, connecting) is what turns captures into knowledge — this drives the inbox workflow (§6) and AI pipeline (§8).

## 2. Unique IDs and file naming

zettelkasten.de discusses four ID schemes and **recommends time-based IDs for digital Zettelkasten** (human-readable, manually creatable, software-independent, migration-proof). Luhmann-style Folgezettel IDs (1, 1a, 1a1, 1a2b) are described as suited to paper; do NOT implement them as primary IDs. Title-as-ID is rejected as fragile (renames break links).

**ID spec:**
- Format: `YYYYMMDDHHMM` (12 digits, local time), e.g. `202607141230`. Matches The Archive / Zettlr / Obsidian Zettelkasten-prefix conventions.
- Collision rule (two notes in the same minute): extend to 14 digits with seconds `YYYYMMDDHHMMSS` (zettelkasten.de's own escalation), or bump minute by 1. Deterministic: try 12-digit; if taken, use 14-digit; if still taken, increment seconds.
- IDs are immutable for the life of the note. ID is minted at note creation (for AI-generated notes: at draft creation, kept on approval).
- Store the ID **redundantly**: in the filename AND in the frontmatter (The Archive does exactly this). zettelkasten.de note: "Note identity and file system representation are ultimately not the same thing" — the ID, not the path, is the canonical identity.

**Filename pattern:**
```
<id>-<title-slug>.md        e.g. 202607141230-atomicity-enables-recombination.md
```
- Slug: lowercase ASCII, hyphens, diacritics folded, max ~60 chars (use package:slugify, defaults do this).
- Renaming a title re-slugs the filename but the ID prefix never changes, so links (which target the ID) never break. Also accept/import `<id> <Title With Spaces>.md` (The Archive style) — resolution is by ID prefix, so both coexist.

**ID generation (Dart):**
```dart
String mintId(DateTime now, bool Function(String) exists) {
  String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  final base = '${now.year}${p(now.month)}${p(now.day)}${p(now.hour)}${p(now.minute)}';
  if (!exists(base)) return base;
  final withSec = '$base${p(now.second)}';
  var candidate = withSec;
  var s = now.second;
  while (exists(candidate)) { s = (s + 1) % 60; candidate = '$base${p(s)}'; }
  return candidate;
}
```

## 3. Linking

- **Syntax**: wikilinks targeting the ID: `[[202607141230]]`. Optional display alias with pipe: `[[202607141230|atomicity note]]`. Also resolve full-filename links `[[202607141230-atomicity-enables-recombination]]` (Obsidian writes these) — resolution algorithm: strip alias after `|`, then match the note whose ID equals, or whose filename starts with, the link target.
- Regex for extraction: `\[\[([^\[\]|]+)(?:\|([^\[\]]+))?\]\]` (group 1 = target, group 2 = alias). Run on body only, not frontmatter. Skip fenced code blocks and inline code (walk the markdown AST — package:markdown `Document.parse` — rather than raw-regexing the whole file, or at minimum strip ``` fences first).
- **Link context is mandatory doctrine**: zettelkasten.de: "If you just add links without any explanation you will not create knowledge." Every link should sit inside a sentence stating WHY the connection matters, e.g. `Investing starts with liquidity: [[202001121202]] You have to have the liquidity to make investment decisions…`. App behavior: when inserting a link, prompt/nudge for a context sentence; AI-suggested links MUST come with a drafted context sentence (§8). Lint rule (soft): flag links that are alone on a line with no surrounding prose.
- **Backlinks**: computed, never stored in the file. Maintain an in-memory/SQLite index `link(source_id, target_id, context_snippet)` rebuilt on file change (watch the vault directory). UI shows a Backlinks panel per note listing source note title + the sentence containing the link (the stored `context_snippet`, ±1 sentence around the link). This matches Obsidian behavior and keeps files portable.
- Unresolved links (target ID not found) are valid — render distinctly and list in a "broken links" report.

## 4. Note anatomy & frontmatter schema

zettelkasten.de's essential parts: (1) unique ID, (2) body in own words, (3) references at the bottom; plus tags and a title. File layout:

```markdown
---
id: "202607141230"
title: "Atomicity enables recombination of ideas"
date: 2026-07-14T12:30:00+02:00
type: zettel
tags: [zettelkasten, atomicity]
references:
  - "@ahrens2017"
  - "https://zettelkasten.de/introduction/"
aliases: []
---
# Atomicity enables recombination of ideas

One idea, written in my own words, understandable without the source.

This is why linking beats folders: [[202607101115]] — atomic notes can be
recombined across topics, which hierarchies forbid.

## References
- Ahrens, *How to Take Smart Notes* (2017), ch. 2 [@ahrens2017]
```

**Exact frontmatter schema (all keys lowercase):**
- `id` (string, required, quoted — YAML would parse 12 digits as int otherwise)
- `title` (string, required; duplicated as the first `# H1` in the body for tool-independence)
- `date` (ISO-8601 datetime, required; creation time = ID time)
- `type` (enum, required): `zettel` | `structure` | `literature` | `inbox`
- `tags` (string list, required, may be empty): plain words, NO leading `#`, lowercase, hyphenated. (Obsidian requires `#`-less tags in frontmatter; `#tag` inline in body is additionally allowed and indexed — zettelkasten.de itself uses inline `#hashtags`.)
- `references` (string list, optional): BibTeX citekeys as `"@key"` (zettelkasten.de uses citekeys via reference managers) and/or raw URLs.
- `aliases` (string list, optional): alternate titles (Obsidian-native key).
- Optional capture provenance (inbox notes only): `source` (`clipboard`|`audio`|`ocr`|`web`|`manual`), `source_url`, `captured` (ISO datetime), `status` (`raw`|`draft`|`needs-review`).
- Zettlr compatibility: Zettlr reads `title` and `keywords`; optionally dual-write `keywords` mirroring `tags`. Zettlr's default ID pattern is also `%Y%m%d%H%M%S`-style, and it detects the ID in filename/body, so our files open cleanly. Obsidian ignores unknown keys (`id`, `type`, `references`) harmlessly and natively understands `tags`, `aliases`, `date`.
- Tag doctrine (zettelkasten.de posts/no-categories, posts/object-tags-vs-topic-tags): tags over folders/categories; prefer **object tags** (specific things the note is about, e.g. `spaced-repetition`) over broad **topic tags** (e.g. `learning`). Cap suggestions at ~5.

**Parsing (Dart, verified packages):**
```dart
import 'package:front_matter_ml/front_matter_ml.dart' as fm;

final doc = fm.parse(fileContents);          // front_matter_ml 1.2.0
final meta = doc.data as Map?;               // parsed YAML map
final body = doc.content;                    // markdown body
```
Fallback without front_matter_ml (only needs yaml 3.1.3):
```dart
import 'package:yaml/yaml.dart';
final m = RegExp(r'^---\r?\n(.*?)\r?\n---\r?\n', dotAll: true).firstMatch(text);
final meta = m == null ? null : loadYaml(m.group(1)!) as YamlMap?;
final body = m == null ? text : text.substring(m.end);
```
Serialize frontmatter by writing keys manually in a fixed order (id, title, date, type, tags, references, aliases, then provenance) — package:yaml is parse-only; do not reorder keys on rewrite, and preserve unknown keys round-trip.

## 5. Note types

Ahrens' taxonomy (from zettelkasten.de/posts/concepts-sohnke-ahrens-explained/):
- **Fleeting notes**: quick captures "while you are busy doing something else"; rewritten into permanent notes then **discarded within days**.
- **Literature notes**: source references (in Ahrens' actual meaning, entries in a reference manager like Zotero, optionally with brief remarks) — NOT full notes in the archive.
- **Permanent notes (Zettels)**: self-contained, own words, "written as if for print", never discarded.
- **Project notes**: live outside the Zettelkasten, per writing project.

zettelkasten.de's own view: the introduction does not use Ahrens' three-tier vocabulary and the site/forum considers the terms unnecessary and confusion-prone. Their operational model is **workflow components**, which is what the app should implement: **Inbox** (temporary capture) → **Reference manager** (bibliography/citekeys) → **Note archive** (the Zettelkasten proper) (+ transient buffer notes). Map: fleeting note = inbox item (deletable), literature note = `type: literature` file in `references/` keyed by citekey, permanent note = `type: zettel` in the archive.

## 6. Inbox workflow (capture → process → permanent)

1. **Capture**: anything (clipboard, share sheet, audio transcript, OCR) lands as a file in `inbox/` with `type: inbox`, `status: raw`, provenance keys. Zero friction, no ID discipline required yet (still mint an ID so the file is addressable).
2. **Process** (user-driven, AI-assisted, §8): rewrite in own words, split to atomic notes, add links with context, tags, references.
3. **Promote**: resulting notes get `type: zettel`, move to `zettel/`, `status` key removed. The inbox original is deleted (Ahrens: fleeting notes are discarded) or optionally archived under `assets/raw/` if the user enables "keep originals".
4. Inbox hygiene: show inbox count badge; surface stale items (>7 days). Guard against the **Collector's Fallacy** (zettelkasten.de/posts/collectors-fallacy/): capturing is not knowing — the app must make processing easier than hoarding.

## 7. Structure notes / hub notes

- Definition (zettelkasten.de): a structure note is a "Meta-Note: a Zettel about other Zettels and their relationships" — a curated table of contents / entry point into a topic.
- Implementation: ordinary markdown note with `type: structure`, body is prose + (possibly nested) lists of `[[id]]` links, each ideally with a context phrase. Supports hierarchies (nested lists), sequences (`a → b → c` argument chains), and overlaps (a note may appear in many structure notes — semilattice, not tree).
- They live in the same flat `zettel/` folder (identity by frontmatter, not location) — do NOT create topic folders.
- App features: "Structure notes containing this note" panel; quick-add current note to a structure note; suggest creating one when ≥5–7 notes cluster (§8.6). Luhmann's register analogue: a top-level `Home`/index structure note listing only the most important entry-point notes per theme.

## 8. AI ingestion pipeline (raw capture → Zettelkasten)

Doctrinal constraints: notes must end up in the user's own words with link context; therefore **the AI proposes, the human disposes**. Nothing is auto-promoted to `zettel/`; nothing is ever auto-deleted. Every AI artifact is marked (`status: draft`, `created_by: assistant` allowed as extra key) and sits in `inbox/` until approved.

Pipeline stages for a raw capture (clipboard text / audio transcript / OCR result):
1. **Normalize**: strip boilerplate (nav text from OCR/web, filler words from transcripts), fix OCR artifacts, keep an untouched copy of the raw input (frontmatter `source`, `source_url`, `captured`).
2. **Segment into atomic candidates**: split by *idea*, not by paragraph. Test per candidate: (a) can it be titled with a single declarative assertion? (b) is it understandable standalone? (c) does it contain exactly one claim/concept? Merge fragments that fail (b); split chunks that fail (c). Output 1–N candidate notes; a 20-line clipboard dump typically yields 1–4.
3. **Draft each note**: title = full declarative statement (assertion-style, e.g. "Atomicity enables recombination of ideas", not "Atomicity"); body = paraphrase (never verbatim beyond short attributed quotes), self-contained; `## References` section carrying `source_url`/citekey; mint ID per note.
4. **Suggest links**: search the existing archive (hybrid: FTS over title/body/tags + embedding similarity if available; fall back to FTS only). For each of the top ≤5 matches, generate a **context sentence** explaining the relationship, e.g. "This extends [[202601021530]] because…". Never emit a bare `[[id]]`. Each suggestion is individually accept/reject in review UI. Also propose the reverse edit ("add link back from note X?") as a separate suggestion.
5. **Suggest tags**: prefer reusing the vault's existing tag vocabulary (offer fuzzy matches before new tags); prefer object tags over topic tags; ≤5 per note; lowercase-hyphenated.
6. **Duplicate/merge detection**: before finalizing a draft, check similarity vs existing notes; if near-duplicate (high overlap), propose "link to / extend existing note [[id]]" instead of creating a new one.
7. **Structure-note maintenance**: if the new notes plus existing ones form a cluster of ≥5–7 around a theme with no structure note, propose creating one; if a relevant structure note exists, propose appending the new `[[id]]`s with context lines.
8. **Review gate**: user sees a diff-style review (drafted notes, links+contexts, tags, structure-note edits), edits freely, approves per note. On approval: `type: inbox→zettel`, file moves `inbox/` → `zettel/`, provenance `status` removed, backlink index updated, raw capture deleted/archived per setting.

## 9. Folder layout & file conventions

```
vault/
  inbox/          # captures + AI drafts (type: inbox, status: raw|draft|needs-review)
  zettel/         # FLAT archive: all permanent notes incl. structure notes
  references/     # literature notes, one per source: <citekey>.md (type: literature)
  assets/         # images/audio/pdf attachments; assets/raw/ for kept originals
  .zk/            # app-private: index.sqlite (links, tags, FTS), config.yaml — gitignored
```
- Markdown dialect: CommonMark + GFM tables/task lists (package:markdown 7.3.1: `ExtensionSet.gitHubFlavored`), wikilinks per §3, `#inline-tags`, `@citekeys` in references.
- Encoding UTF-8, LF newlines, files end with newline. The vault must remain fully usable in Obsidian/Zettlr/plain git with the app absent — no proprietary data outside `.zk/`.
