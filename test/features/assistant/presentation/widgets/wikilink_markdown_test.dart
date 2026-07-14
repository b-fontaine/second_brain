import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/features/assistant/presentation/bloc/chat_state.dart';
import 'package:second_brain/features/assistant/presentation/widgets/chat_message_bubble.dart';
import 'package:second_brain/features/assistant/presentation/widgets/wikilink_markdown.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';

void main() {
  group('transformWikilinksToMarkdownLinks', () {
    test('rewrites bare [[id]] wikilinks into zettel links', () {
      expect(
        transformWikilinksToMarkdownLinks(
          'Voir [[20260101120000]] pour la suite.',
        ),
        'Voir [20260101120000](zettel:20260101120000) pour la suite.',
      );
    });

    test('rewrites aliased [[id|label]] wikilinks keeping the label', () {
      expect(
        transformWikilinksToMarkdownLinks(
          'Voir [[20260101120000|mémoire de travail]].',
        ),
        'Voir [mémoire de travail](zettel:20260101120000).',
      );
    });

    test('leaves fenced code blocks untouched', () {
      const source = 'Avant [[20260101120000]]\n```\n[[20260101120000]]\n```';
      expect(
        transformWikilinksToMarkdownLinks(source),
        'Avant [20260101120000](zettel:20260101120000)'
        '\n```\n[[20260101120000]]\n```',
      );
    });
  });

  group('zettelIdFromHref', () {
    test('extracts a valid zettel id', () {
      expect(zettelIdFromHref('zettel:20260101120000'), '20260101120000');
    });

    test('resolves filename-style targets to their leading id', () {
      expect(
        zettelIdFromHref('zettel:20260101120000-notes-atomiques'),
        '20260101120000',
      );
    });

    test('returns null for foreign or missing links', () {
      expect(zettelIdFromHref('https://example.com'), isNull);
      expect(zettelIdFromHref('zettel:pas-un-id'), isNull);
      expect(zettelIdFromHref(null), isNull);
    });
  });

  group('image sources', () {
    testWidgets('blocks remote markdown images', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: WikilinkMarkdownBody(
              data: '![beacon](https://attacker.example/x.png)',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('Image externe non chargée'), findsOneWidget);
    });
  });

  group('clickable citations', () {
    GoRouter buildRouter(ChatMessage message) {
      return GoRouter(
        initialLocation: '/chat',
        routes: [
          GoRoute(
            path: '/chat',
            builder: (context, state) =>
                Scaffold(body: ChatMessageBubble(message: message)),
          ),
          GoRoute(
            path: '/note/:id',
            builder: (context, state) =>
                Scaffold(body: Text('détail ${state.pathParameters['id']}')),
          ),
        ],
      );
    }

    testWidgets('tapping an inline [[id]] citation opens the note detail', (
      tester,
    ) async {
      final router = buildRouter(
        ChatMessage.assistant(
          text: 'La mémoire de travail est limitée [[20260101120000]].',
        ),
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );

      await tester.tapOnText(find.textRange.ofSubstring('20260101120000'));
      await tester.pumpAndSettle();

      expect(find.text('détail 20260101120000'), findsOneWidget);
    });

    testWidgets('tapping a cited source chip opens the note detail', (
      tester,
    ) async {
      final router = buildRouter(
        ChatMessage.assistant(
          text: 'Réponse sans citation inline.',
          citedZettels: [ZettelId.fromString('20260101120000')],
        ),
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );

      await tester.tap(find.text('20260101120000'));
      await tester.pumpAndSettle();

      expect(find.text('détail 20260101120000'), findsOneWidget);
    });
  });
}
