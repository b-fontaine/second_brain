import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/core/widgets/adaptive_scaffold.dart';
import 'package:second_brain/features/capture/presentation/widgets/seed_dial.dart';

void main() {
  Widget buildSubject({
    required double width,
    int selectedIndex = 0,
    ValueChanged<int>? onDestinationSelected,
    bool openSeedDial = false,
  }) {
    return MaterialApp(
      // The seed bar/button and the dial read the SerreTokens extension.
      theme: AppTheme.light,
      home: MediaQuery(
        // Overrides the window metrics so Breakpoints sees [width].
        data: MediaQueryData(size: Size(width, 900)),
        child: AdaptiveScaffold(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected ?? (_) {},
          // Stub action: the real SyncStatusIndicator needs the DI container.
          appBarActions: const [SizedBox.shrink()],
          openSeedDial: openSeedDial,
          child: const Text('corps'),
        ),
      ),
    );
  }

  group('layout switching', () {
    testWidgets('shows the seed bottom bar on compact widths', (tester) async {
      await tester.pumpWidget(buildSubject(width: 500));

      expect(find.byKey(const Key('seed-navigation-bar')), findsOneWidget);
      expect(find.byKey(const Key('seed-button')), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('corps'), findsOneWidget);
    });

    testWidgets('shows a NavigationRail with a divider on expanded widths', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(width: 1200));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byKey(const Key('seed-navigation-bar')), findsNothing);
      expect(find.byType(VerticalDivider), findsOneWidget);
      // The seed button floats as a FAB.
      expect(find.byKey(const Key('seed-button')), findsOneWidget);
      expect(find.text('corps'), findsOneWidget);
    });

    testWidgets('switches exactly at the 840 dp breakpoint', (tester) async {
      await tester.pumpWidget(buildSubject(width: 839));
      expect(find.byKey(const Key('seed-navigation-bar')), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      await tester.pumpWidget(buildSubject(width: 840));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byKey(const Key('seed-navigation-bar')), findsNothing);
    });
  });

  group('destinations', () {
    testWidgets('offers Assistant and Explorer on compact', (tester) async {
      await tester.pumpWidget(buildSubject(width: 500, selectedIndex: 1));

      // Also the AppBar title, since tab 1 (Assistant) is selected.
      expect(find.text('Assistant'), findsNWidgets(2));
      expect(find.text('Explorer'), findsOneWidget);
    });

    testWidgets('tapping the bottom destinations reports the tab index', (
      tester,
    ) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        buildSubject(
          width: 500,
          selectedIndex: 1,
          onDestinationSelected: tapped.add,
        ),
      );

      // Assistant is selected: its icon is filled, Explorer's is outlined.
      await tester.tap(find.byIcon(Icons.park_outlined));
      await tester.tap(find.byIcon(Icons.chat_bubble));
      expect(tapped, [0, 1]);
    });

    testWidgets('tapping a rail destination reports the tab index', (
      tester,
    ) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        buildSubject(width: 1200, onDestinationSelected: tapped.add),
      );

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      expect(tapped, [1]);
    });

    testWidgets('maps the selected tab to the rail order (Assistant first)', (
      tester,
    ) async {
      // Tab 0 (Explorer) sits at visual position 1 on the rail.
      await tester.pumpWidget(buildSubject(width: 1200, selectedIndex: 0));
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
        1,
      );

      await tester.pumpWidget(buildSubject(width: 1200, selectedIndex: 1));
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
        0,
      );
    });
  });

  group('app bar', () {
    testWidgets('titles the current section', (tester) async {
      await tester.pumpWidget(buildSubject(width: 1200, selectedIndex: 1));

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Assistant'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('has no settings gear anymore (moved to rail/Explorer)', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(width: 500));

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.settings_outlined),
        ),
        findsNothing,
      );
    });
  });

  group('rail settings gear', () {
    testWidgets('shows an enabled settings button at the rail bottom', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(width: 1200));

      final button = tester.widget<IconButton>(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.widgetWithIcon(IconButton, Icons.settings_outlined),
        ),
      );
      // Wired to `context.push('/settings')`; navigation itself is
      // covered by the settings BDD suite (real router).
      expect(button.onPressed, isNotNull);
      expect(button.tooltip, 'Réglages');
    });
  });

  group('seed dial', () {
    testWidgets('opens from the compact seed button and closes on scrim tap', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(width: 500));
      expect(find.byType(SeedDial), findsNothing);

      await tester.tap(find.byKey(const Key('seed-button')));
      await tester.pumpAndSettle();
      expect(find.text('Dicter'), findsOneWidget);
      expect(find.text('Coller'), findsOneWidget);
      expect(find.text('Ajouter un fichier'), findsOneWidget);

      // Aim at a corner of the scrim: its center is covered by the chips.
      final scrim = find.byKey(const Key('seed-dial-scrim'));
      await tester.tapAt(tester.getTopLeft(scrim) + const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(SeedDial), findsNothing);
    });

    testWidgets('opens from the expanded FAB', (tester) async {
      await tester.pumpWidget(buildSubject(width: 1200));

      await tester.tap(find.byKey(const Key('seed-button')));
      await tester.pumpAndSettle();

      expect(find.byType(SeedDial), findsOneWidget);
    });

    testWidgets('openSeedDial opens the dial once and does not reopen after '
        'dismissal', (tester) async {
      await tester.pumpWidget(buildSubject(width: 500, openSeedDial: true));
      await tester.pumpAndSettle();
      expect(find.byType(SeedDial), findsOneWidget);

      // Aim at a corner of the scrim: its center is covered by the chips.
      final scrim = find.byKey(const Key('seed-dial-scrim'));
      await tester.tapAt(tester.getTopLeft(scrim) + const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(SeedDial), findsNothing);

      // Same flag still set (the ?semer=1 location did not change): the
      // dial must stay closed until the next rising edge.
      await tester.pumpWidget(buildSubject(width: 500, openSeedDial: true));
      await tester.pumpAndSettle();
      expect(find.byType(SeedDial), findsNothing);
    });
  });

  group('rail hover', () {
    testWidgets('extends while hovered and collapses on exit', (tester) async {
      await tester.pumpWidget(buildSubject(width: 1200));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.byType(NavigationRail)));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );

      await gesture.moveTo(tester.getCenter(find.text('corps')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isFalse,
      );
    });
  });
}
