import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/features/capture/presentation/widgets/seed_dial.dart';

void main() {
  Widget buildSubject({
    required VoidCallback onDismiss,
    VoidCallback? onDictate,
    VoidCallback? onPaste,
    VoidCallback? onAddFile,
    bool disableAnimations = false,
    bool alignEnd = false,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: SeedDial(
            onDismiss: onDismiss,
            alignEnd: alignEnd,
            bottomInset: 98,
            // Stub actions: the real ones push the capture flow, which
            // needs the DI container.
            onDictate: onDictate ?? () {},
            onPaste: onPaste ?? () {},
            onAddFile: onAddFile ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows the three seeding chips with their formats', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(onDismiss: () {}));
    await tester.pumpAndSettle();

    expect(find.text('Dicter'), findsOneWidget);
    expect(find.text('voix → note, hors-ligne'), findsOneWidget);
    expect(find.text('Coller'), findsOneWidget);
    expect(find.text('texte · markdown · image · audio'), findsOneWidget);
    expect(find.text('Ajouter un fichier'), findsOneWidget);
    expect(find.text('.md · .txt · image · audio'), findsOneWidget);
  });

  testWidgets('tapping the scrim dismisses', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(buildSubject(onDismiss: () => dismissed++));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seed-dial-scrim')));
    expect(dismissed, 1);
  });

  testWidgets('each chip dismisses then runs its action', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      buildSubject(
        onDismiss: () => calls.add('dismiss'),
        onDictate: () => calls.add('dictate'),
        onPaste: () => calls.add('paste'),
        onAddFile: () => calls.add('file'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seed-dial-dictate')));
    await tester.tap(find.byKey(const Key('seed-dial-paste')));
    await tester.tap(find.byKey(const Key('seed-dial-file')));

    expect(calls, [
      'dismiss',
      'dictate',
      'dismiss',
      'paste',
      'dismiss',
      'file',
    ]);
  });

  testWidgets('skips the entrance animation under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(onDismiss: () {}, disableAnimations: true),
    );
    // A single frame, no settling: the dial must already be fully shown.
    await tester.pump();

    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(const Key('seed-dial-scrim')),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 1);
  });
}
