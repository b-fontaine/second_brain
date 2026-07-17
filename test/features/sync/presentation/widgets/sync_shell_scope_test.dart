import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/core/theme/serre_tokens.dart';
import 'package:second_brain/core/widgets/adaptive_scaffold.dart';
import 'package:second_brain/features/sync/domain/entities/sync_status.dart';
import 'package:second_brain/features/sync/presentation/bloc/sync_status_cubit.dart';
import 'package:second_brain/features/sync/presentation/widgets/sync_shell_scope.dart';

class MockSyncStatusCubit extends MockCubit<SyncStatusState>
    implements SyncStatusCubit {}

void main() {
  late MockSyncStatusCubit cubit;

  setUp(() {
    cubit = MockSyncStatusCubit();
  });

  SyncStatusReady ready({
    SyncState state = SyncState.upToDate,
    int pendingCommits = 0,
    int conflictCount = 0,
    bool isOnline = true,
  }) {
    return SyncStatusReady(
      status: SyncStatus(
        state: state,
        pendingCommits: pendingCommits,
        conflictCount: conflictCount,
      ),
      isOnline: isOnline,
    );
  }

  Future<void> pumpShell(
    WidgetTester tester, {
    required SyncStatusState initialState,
    Stream<SyncStatusState>? states,
  }) async {
    whenListen(
      cubit,
      states ?? const Stream<SyncStatusState>.empty(),
      initialState: initialState,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SyncShellScope(
          cubit: cubit,
          child: const Scaffold(
            body: SyncOfflineBanner(child: Text('contenu de l’onglet')),
          ),
        ),
      ),
    );
  }

  group('offline banner', () {
    testWidgets('appears while local commits wait for connectivity', (
      tester,
    ) async {
      await pumpShell(
        tester,
        initialState: ready(
          state: SyncState.pendingPush,
          pendingCommits: 3,
          isOnline: false,
        ),
      );

      expect(find.byKey(const Key('sync-offline-banner')), findsOneWidget);
      expect(
        find.text(
          '3 notes attendent la pluie — synchronisation à la reconnexion',
        ),
        findsOneWidget,
      );
      // The tab content stays below the banner.
      expect(find.text('contenu de l’onglet'), findsOneWidget);
    });

    testWidgets('uses the singular for one pending note', (tester) async {
      await pumpShell(
        tester,
        initialState: ready(
          state: SyncState.pendingPush,
          pendingCommits: 1,
          isOnline: false,
        ),
      );

      expect(
        find.text('1 note attend la pluie — synchronisation à la reconnexion'),
        findsOneWidget,
      );
    });

    testWidgets('stays hidden while online, even with pending commits', (
      tester,
    ) async {
      await pumpShell(
        tester,
        initialState: ready(state: SyncState.pendingPush, pendingCommits: 3),
      );

      expect(find.byKey(const Key('sync-offline-banner')), findsNothing);
    });

    testWidgets('stays hidden offline while everything is pushed', (
      tester,
    ) async {
      await pumpShell(tester, initialState: ready(isOnline: false));

      expect(find.byKey(const Key('sync-offline-banner')), findsNothing);
    });
  });

  group('conflict toast', () {
    testWidgets('shows the pedagogical toast on a rising conflict count', (
      tester,
    ) async {
      final states = StreamController<SyncStatusState>();
      addTearDown(states.close);
      await pumpShell(
        tester,
        initialState: ready(),
        states: states.stream,
      );

      states.add(ready(conflictCount: 1));
      await tester.pump();
      await tester.pump();

      expect(find.text(SyncShellScope.conflictToastMessage), findsOneWidget);

      // Flush the SnackBar lifetime so the test ends settled.
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
    });

    testWidgets('does not repeat the toast while the count stays raised', (
      tester,
    ) async {
      final states = StreamController<SyncStatusState>();
      addTearDown(states.close);
      await pumpShell(
        tester,
        initialState: ready(conflictCount: 1),
        states: states.stream,
      );

      // 1 → 2 is not a rising edge from zero: no new toast.
      states.add(ready(conflictCount: 2));
      await tester.pump();
      await tester.pump();

      expect(find.text(SyncShellScope.conflictToastMessage), findsNothing);
    });
  });

  group('sync status dot', () {
    Future<void> pumpDot(
      WidgetTester tester,
      SyncStatusState initialState,
    ) async {
      whenListen(
        cubit,
        const Stream<SyncStatusState>.empty(),
        initialState: initialState,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SyncShellScope(
            cubit: cubit,
            child: const Scaffold(body: Center(child: SyncStatusDot())),
          ),
        ),
      );
    }

    Color dotColor(WidgetTester tester) {
      final container = tester.widget<Container>(
        find.byKey(const Key('sync-status-dot')),
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    testWidgets('renders nothing without a provided cubit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SyncStatusDot()),
        ),
      );

      expect(find.byKey(const Key('sync-status-dot')), findsNothing);
    });

    testWidgets('is green when everything is synchronized', (tester) async {
      await pumpDot(tester, ready());

      final tokens = AppTheme.light.extension<SerreTokens>()!;
      expect(dotColor(tester), tokens.accent);
    });

    testWidgets('turns amber offline, with pending commits or after a '
        'conflict', (tester) async {
      final tokens = AppTheme.light.extension<SerreTokens>()!;

      await pumpDot(tester, ready(isOnline: false));
      expect(dotColor(tester), tokens.ambre);

      await pumpDot(
        tester,
        ready(state: SyncState.pendingPush, pendingCommits: 2),
      );
      expect(dotColor(tester), tokens.ambre);

      await pumpDot(tester, ready(conflictCount: 1));
      expect(dotColor(tester), tokens.ambre);
    });

    testWidgets('stays hidden for a local-only vault', (tester) async {
      await pumpDot(tester, ready(state: SyncState.localOnly));

      expect(find.byKey(const Key('sync-status-dot')), findsNothing);
    });

    testWidgets('sits next to the settings gear of the expanded rail', (
      tester,
    ) async {
      whenListen(
        cubit,
        const Stream<SyncStatusState>.empty(),
        initialState: ready(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            // Overrides the window metrics so Breakpoints sees a desktop.
            data: const MediaQueryData(size: Size(1200, 900)),
            child: SyncShellScope(
              cubit: cubit,
              child: AdaptiveScaffold(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                // Stub action: the real indicator would hit the DI
                // container (contract shared with adaptive_scaffold_test).
                appBarActions: const [SizedBox.shrink()],
                child: const Text('corps'),
              ),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byKey(const Key('sync-status-dot')),
        ),
        findsOneWidget,
      );
    });
  });
}
