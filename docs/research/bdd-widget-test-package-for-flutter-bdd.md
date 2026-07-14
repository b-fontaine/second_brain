# bdd_widget_test package for Flutter BDD testing + standard versions for bloc/DI/functional stack (verified on pub.dev 2026-07-14)

## Recommandation

bdd_widget_test ^2.1.4 (pub.dev, publisher leushchenko.com, published 2026-06-01) — generates plain Flutter widget tests from Gherkin .feature files via build_runner. Combine with bloc_test ^10.0.0 and mocktail ^1.0.5 for bloc-level unit tests alongside the BDD widget tests.

## Support plateformes

{"android": true, "ios": true, "windows": true, "linux": true, "macos": true}

## Fallback

bdd_widget_test is a pure dev-dependency that emits standard flutter_test widget tests, so there is no platform to fall back from. If the team rejects codegen, the fallback is hand-written flutter_test widget tests organized in group()/testWidgets() mirroring Gherkin scenarios (that is literally what the generator produces), or flutter_gherkin (runtime Gherkin interpreter, but far less maintained). For Either types, if fpdart is rejected, dartz 0.10.1 still works but has been unmaintained since Dec 2021 — prefer fpdart.

## Entrées pubspec

- `# dependencies:`
- `flutter_bloc: ^9.1.1`
- `bloc: ^9.2.1`
- `get_it: ^9.2.1`
- `injectable: ^3.0.0`
- `equatable: ^2.1.0`
- `fpdart: ^1.2.0`
- `# dev_dependencies:`
- `bdd_widget_test: ^2.1.4`
- `build_runner: ^2.15.2`
- `bloc_test: ^10.0.0`
- `mocktail: ^1.0.5`
- `injectable_generator: ^3.1.0`

## Setup plateforme

No platform-specific configuration (Info.plist / AndroidManifest / entitlements) is needed — all listed packages are pure Dart/Flutter and the testing packages are dev-only, running on the host via `flutter test`. SDK constraints to respect: build_runner 2.15.2 needs Dart >=3.11.0; injectable_generator 3.1.0 needs Dart >=3.12.0; injectable 3.0.0 needs Dart >=3.8.0 and get_it >=8.3.0 <10.0.0 (get_it 9.2.1 satisfies this). Use a current stable Flutter SDK (Dart 3.12+). Workflow: 1) add pubspec entries, `flutter pub get`; 2) create `.feature` files under test/; 3) `dart run build_runner watch --delete-conflicting-outputs` during development (or `build` one-shot / in CI) — this single command generates BDD tests, step stubs, AND injectable's DI config; 4) implement/edit files in test/step/; 5) `flutter test` (optionally `--tags <tag>` for tagged scenarios). Optional build.yaml at project root to customize stepFolderName, testMethodName (e.g. testGoldens), customHeaders imports, and externalSteps.

## Notes API

## VERIFIED VERSIONS (pub.dev API, checked 2026-07-14)
- bdd_widget_test: 2.1.4 (2026-06-01)
- build_runner: 2.15.2 (2026-07-13; requires Dart >=3.11.0)
- flutter_bloc: 9.1.1 (latest stable, 2025-05-02)
- bloc: 9.2.1 (2026-05-12)
- bloc_test: 10.0.0 (2025-01-12; depends on bloc ^9.x — compatible with flutter_bloc 9.1.1)
- mocktail: 1.0.5 (2026-04-10)
- get_it: 9.2.1 (2026-02-20)
- injectable: 3.0.0 (2026-04-20; requires Dart >=3.8.0, get_it >=8.3.0 <10.0.0 — get_it 9.2.1 OK)
- injectable_generator: 3.1.0 (2026-06-14; requires Dart >=3.12.0 — if your Flutter SDK's Dart is older, pin injectable_generator lower, e.g. ^3.0.0)
- equatable: 2.1.0 (2026-07-05; 3.0.0-dev prereleases exist, stay on 2.1.0)
- fpdart: 1.2.0 (2025-10-29) — RECOMMENDED for Either
- dartz: 0.10.1 (2021-12-03, unmaintained — avoid for new code)

## HOW bdd_widget_test WORKS
1. Write `*.feature` files (Gherkin) anywhere under `test/` (subfolders fine — the example repo has `test/features/sub-feature/...`).
2. Run `dart run build_runner watch --delete-conflicting-outputs` (or `build` for one-shot).
3. For each `foo.feature` the builder generates `foo_test.dart` next to it (marked GENERATED CODE - DO NOT MODIFY BY HAND, regenerated on every feature change) plus one stub file per step in `test/step/` (function per step). STEP FILES ARE GENERATED ONCE and never overwritten — they are yours to edit; this is where custom step logic lives.
4. Run with plain `flutter test` (they are ordinary testWidgets tests; IDE run buttons work).

Step-name mapping: Gherkin keywords (Given/When/Then/And/But) are ignored for matching. "I see {'0'} text" → file `test/step/i_see_text.dart`, function `iSeeText`. Params in `{...}` are raw Dart code injected as typed function args: `{'0'}` → String, `{42}` → int, `{Icons.add}` → IconData. `<param>` placeholders bind Scenario Outline Examples columns.

Well-known built-in steps get real implementations generated (not stubs): "the app is running", "I see {..} text", "I don't see {..} text", "I tap {..} icon", "I see {..} icon", "I don't see {..} icon", "I see {..} widget", "I don't see {..} widget", "I see multiple {..} texts/widgets", "I see exactly {..} {..} widgets", "I see {..} rich text", "I don't see {..} rich text", "I enter {'text'} into {1} input field", "I see enabled/disabled elevated button", "I wait", "I dismiss the page". Unknown steps generate `throw UnimplementedError();` stubs for you to fill.

Gherkin support: Feature, Scenario, Scenario Outline + Examples (one testWidgets generated per Examples row, named `Outline: <name> (val1, val2)`), Background (becomes `bddSetUp` called at start of every scenario), After (becomes `bddTearDown` in a try/finally — runs even on failure), Tags (`@important` above Feature/Scenario → run subset via `flutter test --tags important`), DataTables (table under a step → step function gets extra `bdd.DataTable` param from `package:bdd_widget_test/data_table.dart`; use `dataTable.asMaps()`), per-scenario directives as comments (e.g. `# @testMethodName: testGoldens`).

## PUBSPEC (dev_dependencies for the full test stack)
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  bdd_widget_test: ^2.1.4
  build_runner: ^2.15.2
  bloc_test: ^10.0.0
  mocktail: ^1.0.5
  injectable_generator: ^3.1.0
```
Regular dependencies: flutter_bloc ^9.1.1, get_it ^9.2.1, injectable ^3.0.0, equatable ^2.1.0, fpdart ^1.2.0.

## build.yaml OPTIONS (optional, project root)
```yaml
targets:
  $default:
    builders:
      bdd_widget_test|featureBuilder:
        options:
          stepFolderName: step            # default 'step', relative to the feature file
          addHooks: true                  # generate hook files
          hookFolderName: hook
          testMethodName: testWidgets     # or testGoldens / patrolTest
          customHeaders:
            - "import 'package:mocktail/mocktail.dart';"
          externalSteps:
            - package:my_shared_steps/steps.dart
          relativeToTestFolder: false
```

## COMPLETE VERIFIED EXAMPLE
### test/counter.feature
```gherkin
Feature: Counter

    Background:
        Given the app is running

    Scenario: Initial counter value is 0
        Then I see {'0'} text

    Scenario: Add button increments the counter
        When I tap {Icons.add} icon
        Then I see {'1'} text

    Scenario Outline: Plus button increases the counter
        When I tap {Icons.add} icon <times> times
        Then I see <result> text

        Examples:
        | times | result |
        |    0  |   '0'  |
        |    1  |   '1'  |
        |   42  |  '42'  |
```

### Generated test/counter_test.dart (verbatim shape from the package's own example output)
```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running.dart';
import './step/i_see_text.dart';
import './step/i_tap_icon.dart';
import './step/i_tap_icon_times.dart';

void main() {
  group('''Counter''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunning(tester);
    }

    testWidgets('''Initial counter value is 0''', (tester) async {
      await bddSetUp(tester);
      await iSeeText(tester, '0');
    });
    testWidgets('''Add button increments the counter''', (tester) async {
      await bddSetUp(tester);
      await iTapIcon(tester, Icons.add);
      await iSeeText(tester, '1');
    });
    testWidgets('''Outline: Plus button increases the counter (0, '0')''',
        (tester) async {
      await bddSetUp(tester);
      await iTapIconTimes(tester, Icons.add, 0);
      await iSeeText(tester, '0');
    });
    // ... one testWidgets per Examples row (1,'1') and (42,'42')
  });
}
```
(When an `After:` block exists, each body is wrapped in try { ... } finally { await bddTearDown(tester); }.)

### Step implementations (test/step/) — generated, then edited by you
```dart
// test/step/the_app_is_running.dart  (EDIT THIS: pump your real app + DI setup)
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/main.dart';

Future<void> theAppIsRunning(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
}

// test/step/i_see_text.dart  (built-in impl, generated as-is)
import 'package:flutter_test/flutter_test.dart';

Future<void> iSeeText(WidgetTester tester, String text) async {
  expect(find.text(text), findsOneWidget);
}

// test/step/i_tap_icon.dart  (built-in impl, generated as-is)
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> iTapIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pump();
}
```

### DataTable custom step (from the package's own example)
Feature:
```gherkin
Scenario: Available songs
  Given the following {'Good'} songs
    | 'artist'      | 'title'              |
    | 'The Beatles' | 'Let It Be'          |
    | 'Camel'       | 'Slow yourself down' |
```
Generated stub you implement:
```dart
import 'package:bdd_widget_test/data_table.dart' as bdd;
import 'package:flutter_test/flutter_test.dart';

Future<void> theFollowingSongs(
  WidgetTester tester,
  String param1,
  bdd.DataTable dataTable,
) async {
  final rows = dataTable.asMaps(); // List<Map<String,dynamic>> keyed by header row
  // seed repository / mock with rows...
}
```

## COMBINING WITH flutter_bloc + get_it/injectable + mocktail
Pattern: the "the app is running" step is your composition root for tests. Reset get_it, register mocktail mocks for repositories/data sources, then pump the app so real Blocs run against mocked edges:
```dart
// test/step/the_app_is_running.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:my_app/app.dart';
import 'package:my_app/features/notes/domain/notes_repository.dart';

class MockNotesRepository extends Mock implements NotesRepository {}

Future<void> theAppIsRunning(WidgetTester tester) async {
  final getIt = GetIt.instance;
  await getIt.reset();
  final repo = MockNotesRepository();
  when(() => repo.getNotes()).thenAnswer((_) async => right(<Note>[]));
  getIt.registerSingleton<NotesRepository>(repo);
  // register real Bloc factories or call configureDependencies(environment: 'test') if using injectable @Environment
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}
```
Bloc unit tests live separately (plain dart tests, not BDD) using bloc_test 10.0.0:
```dart
blocTest<NotesBloc, NotesState>(
  'emits [loading, loaded] when NotesRequested succeeds',
  setUp: () => when(() => repo.getNotes()).thenAnswer((_) async => right([note])),
  build: () => NotesBloc(repo),
  act: (bloc) => bloc.add(const NotesRequested()),
  expect: () => [const NotesState.loading(), NotesState.loaded([note])],
);
```
mocktail gotcha: register fallback values for non-primitive matchers once: `setUpAll(() { registerFallbackValue(FakeNotesEvent()); });` when using any() with custom types.

## GOTCHAS
- Generated `*_test.dart` files are overwritten on every feature change; step files are NOT — safe to edit, but if you rename a step in the feature file a NEW stub file is created and the old one is orphaned (delete manually).
- `--delete-conflicting-outputs` is required on first run and in CI.
- bdd_widget_test and injectable_generator share the same build_runner invocation — one `dart run build_runner build --delete-conflicting-outputs` generates both feature tests and DI config.
- `{...}` params are injected verbatim as Dart code — `{CupertinoIcons.back}` needs the import added via `customHeaders` in build.yaml if not already imported.
- Scenario Outline `<param>` values from Examples are also injected verbatim, so strings must be quoted in the table ('0' not 0).
- flutter_bloc latest stable is 9.1.1 even though bloc core is 9.2.1 — this is normal, they version independently within the 9.x line.
- CI order: `flutter pub get` → `dart run build_runner build --delete-conflicting-outputs` → `flutter test`. Consider committing generated `_test.dart` files OR generating in CI; the package works either way.
