import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/widgets/adaptive_scaffold.dart';

void main() {
  Widget buildSubject({
    required double width,
    int selectedIndex = 0,
    ValueChanged<int>? onDestinationSelected,
  }) {
    return MaterialApp(
      home: MediaQuery(
        // Overrides the window metrics so Breakpoints sees [width].
        data: MediaQueryData(size: Size(width, 900)),
        child: AdaptiveScaffold(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected ?? (_) {},
          // Stub action: the real SyncStatusIndicator needs the DI container.
          appBarActions: const [SizedBox.shrink()],
          child: const Text('corps'),
        ),
      ),
    );
  }

  group('layout switching', () {
    testWidgets('shows a bottom NavigationBar on compact widths', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(width: 500));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('corps'), findsOneWidget);
    });

    testWidgets('shows a NavigationRail with a divider on expanded widths', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(width: 1200));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.text('corps'), findsOneWidget);
    });

    testWidgets('switches exactly at the 840 dp breakpoint', (tester) async {
      await tester.pumpWidget(buildSubject(width: 839));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      await tester.pumpWidget(buildSubject(width: 840));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('destinations', () {
    testWidgets('offers the four French destinations on compact', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(width: 500, selectedIndex: 3));

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Capturer'), findsOneWidget);
      expect(find.text('Assistant'), findsOneWidget);
      // Also the AppBar title, since tab 3 is selected.
      expect(find.text('Graphe'), findsNWidgets(2));
    });

    testWidgets('tapping a bottom destination reports its index', (
      tester,
    ) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        buildSubject(width: 500, onDestinationSelected: tapped.add),
      );

      await tester.tap(find.text('Capturer'));
      expect(tapped, [1]);
    });

    testWidgets('tapping a rail destination reports its index', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        buildSubject(width: 1200, onDestinationSelected: tapped.add),
      );

      await tester.tap(find.byIcon(Icons.hub_outlined));
      expect(tapped, [3]);
    });
  });

  group('app bar', () {
    testWidgets('titles the current section', (tester) async {
      await tester.pumpWidget(buildSubject(width: 1200, selectedIndex: 2));

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Assistant'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows an enabled settings button', (tester) async {
      await tester.pumpWidget(buildSubject(width: 500));

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.settings_outlined),
      );
      // Wired to `context.push('/settings')`; navigation itself is
      // covered by the settings BDD suite (real router).
      expect(button.onPressed, isNotNull);
      expect(button.tooltip, 'Réglages');
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
