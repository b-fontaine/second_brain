import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/presentation/pages/assistant_chat_page.dart';
import '../../features/capture/presentation/pages/capture_page.dart';
import '../../features/graph/presentation/pages/graph_page.dart';
import '../../features/setup/domain/repositories/setup_repository.dart';
import '../../features/setup/presentation/pages/setup_page.dart';
import '../../features/sync/presentation/pages/settings_page.dart';
import '../../features/zettel/presentation/pages/notes_home_page.dart';
import '../../features/zettel/presentation/pages/zettel_detail_page.dart';
import '../../features/zettel/presentation/pages/zettel_edit_page.dart';
import '../di/injection.dart';
import '../widgets/adaptive_scaffold.dart';

/// Route paths of the app. Features navigate with
/// `context.go(AppRoutes.chat)` / `context.push(AppRoutes.noteDetail(id))`
/// and never import pages of other features directly.
abstract final class AppRoutes {
  static const notes = '/';
  static const capture = '/capture';
  static const chat = '/chat';
  static const graph = '/graph';
  static const setup = '/setup';
  static const newNote = '/new';
  static const settings = '/settings';

  static String noteDetail(String id) => '/note/$id';

  static String noteEdit(String id) => '/note/$id/edit';
}

/// Paths of the four shell tabs, in [AdaptiveScaffold] destination order.
const List<String> shellTabPaths = [
  AppRoutes.notes,
  AppRoutes.capture,
  AppRoutes.chat,
  AppRoutes.graph,
];

/// Global redirect: as long as no vault is configured, every route except
/// the onboarding leads to `/setup`. A config read failure is treated as
/// "not configured" (the setup screen is the only safe place to recover).
@visibleForTesting
Future<String?> redirectIfNotConfigured(String matchedLocation) async {
  if (matchedLocation == AppRoutes.setup) return null;
  final result = await getIt<SetupRepository>().getConfig();
  final configured = result.fold((_) => false, (config) => config != null);
  return configured ? null : AppRoutes.setup;
}

int _tabIndexFor(String location) {
  if (location.startsWith(AppRoutes.capture)) return 1;
  if (location.startsWith(AppRoutes.chat)) return 2;
  if (location.startsWith(AppRoutes.graph)) return 3;
  return 0;
}

/// Application router: an adaptive shell for the four main tabs, and
/// full-screen routes for onboarding and note detail/edition.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.notes,
  redirect: (context, state) => redirectIfNotConfigured(state.matchedLocation),
  errorBuilder: (context, state) => const RouteNotFoundPage(),
  routes: [
    GoRoute(
      path: AppRoutes.setup,
      builder: (context, state) => const SetupPage(),
    ),
    GoRoute(
      path: AppRoutes.newNote,
      builder: (context, state) => const ZettelEditPage(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/note/:id',
      builder: (context, state) =>
          ZettelDetailPage(zettelId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) =>
              ZettelEditPage(zettelId: state.pathParameters['id']),
        ),
      ],
    ),
    ShellRoute(
      builder: (context, state, child) => AdaptiveScaffold(
        selectedIndex: _tabIndexFor(state.matchedLocation),
        onDestinationSelected: (index) => context.go(shellTabPaths[index]),
        child: child,
      ),
      routes: [
        GoRoute(
          path: AppRoutes.notes,
          builder: (context, state) => const NotesHomePage(),
        ),
        GoRoute(
          path: AppRoutes.capture,
          builder: (context, state) => const CapturePage(),
        ),
        GoRoute(
          path: AppRoutes.chat,
          builder: (context, state) => const AssistantChatPage(),
        ),
        GoRoute(
          path: AppRoutes.graph,
          builder: (context, state) => const GraphPage(),
        ),
      ],
    ),
  ],
);

/// Fallback screen for unmatched locations (invalid deep link, stale
/// restored URL): French message and a way back to the home tab.
class RouteNotFoundPage extends StatelessWidget {
  const RouteNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text('Page introuvable', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.notes),
                child: const Text('Retour à l’accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
