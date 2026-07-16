import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/features/capture/presentation/widgets/window_drop_zone.dart';

void main() {
  group('firstSeedableDroppedPath', () {
    test('accepts notes, images and audio; first supported file wins', () {
      expect(
        firstSeedableDroppedPath([
          DropItemFile('/drop/archive.zip'),
          DropItemFile('/drop/idees.md'),
          DropItemFile('/drop/photo.png'),
        ]),
        '/drop/idees.md',
      );
    });

    test('is case-insensitive on the extension', () {
      expect(
        firstSeedableDroppedPath([DropItemFile('/drop/Capture.PNG')]),
        '/drop/Capture.PNG',
      );
    });

    test('skips folders even when their name carries a supported '
        'extension', () {
      expect(
        firstSeedableDroppedPath([
          DropItemDirectory('/drop/notes.md', const []),
        ]),
        isNull,
      );
    });

    test('returns null when nothing is ingestible', () {
      expect(
        firstSeedableDroppedPath([
          DropItemFile('/drop/binaire.exe'),
          DropItemFile('/drop/sans-extension'),
        ]),
        isNull,
      );
    });
  });

  group('WindowDropZone', () {
    Future<void> pumpZone(
      WidgetTester tester, {
      required bool enabled,
      void Function(String path)? onFileDropped,
      VoidCallback? onUnsupportedDrop,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: WindowDropZone(
              enabledOverride: enabled,
              onFileDropped: onFileDropped ?? (_) {},
              onUnsupportedDrop: onUnsupportedDrop,
              child: const Text('contenu'),
            ),
          ),
        ),
      );
    }

    DropTarget target(WidgetTester tester) =>
        tester.widget<DropTarget>(find.byType(DropTarget));

    DropEventDetails hover() => DropEventDetails(
      localPosition: Offset.zero,
      globalPosition: Offset.zero,
    );

    testWidgets('stays a pure pass-through off desktop', (tester) async {
      await pumpZone(tester, enabled: false);

      expect(find.text('contenu'), findsOneWidget);
      expect(find.byType(DropTarget), findsNothing);
    });

    testWidgets('no overlay is built while nothing hovers (taps must never '
        'be absorbed)', (tester) async {
      await pumpZone(tester, enabled: true);

      expect(find.byType(DropTarget), findsOneWidget);
      expect(find.byKey(const Key('window-drop-overlay')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DropTarget),
          matching: find.byType(IgnorePointer),
        ),
        findsNothing,
      );
    });

    testWidgets('shows the seeding overlay during the hover and hides it on '
        'exit', (tester) async {
      await pumpZone(tester, enabled: true);

      target(tester).onDragEntered!(hover());
      await tester.pump();
      expect(find.byKey(const Key('window-drop-overlay')), findsOneWidget);
      expect(find.text('Déposer pour semer'), findsOneWidget);

      target(tester).onDragExited!(hover());
      await tester.pump();
      expect(find.byKey(const Key('window-drop-overlay')), findsNothing);
    });

    testWidgets('routes the first supported dropped file and closes the '
        'overlay', (tester) async {
      final dropped = <String>[];
      await pumpZone(tester, enabled: true, onFileDropped: dropped.add);

      target(tester).onDragEntered!(hover());
      await tester.pump();
      target(tester).onDragDone!(
        DropDoneDetails(
          files: [
            DropItemFile('/drop/archive.zip'),
            DropItemFile('/drop/idees.md'),
          ],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();

      expect(dropped, ['/drop/idees.md']);
      expect(find.byKey(const Key('window-drop-overlay')), findsNothing);
    });

    testWidgets('signals an unsupported drop instead of seeding', (
      tester,
    ) async {
      final dropped = <String>[];
      var unsupported = 0;
      await pumpZone(
        tester,
        enabled: true,
        onFileDropped: dropped.add,
        onUnsupportedDrop: () => unsupported++,
      );

      target(tester).onDragDone!(
        DropDoneDetails(
          files: [DropItemFile('/drop/binaire.exe')],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();

      expect(dropped, isEmpty);
      expect(unsupported, 1);
    });
  });
}
