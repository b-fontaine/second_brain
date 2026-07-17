import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/presentation/pages/assistant_chat_page.dart';
import '../../features/capture/presentation/pages/pepiniere_page.dart';
import '../../features/explorer/presentation/pages/explorer_page.dart';
import '../../features/setup/domain/repositories/setup_repository.dart';
import '../../features/setup/presentation/pages/models_page.dart';
import '../../features/setup/presentation/pages/setup_page.dart';
import '../../features/sync/presentation/pages/settings_page.dart';
import '../../features/sync/presentation/widgets/sync_shell_scope.dart';
import '../../features/zettel/domain/entities/inbox_item.dart';
import '../../features/zettel/presentation/pages/zettel_detail_page.dart';
import '../../features/zettel/presentation/pages/zettel_edit_page.dart';
import '../di/injection.dart';
import '../widgets/adaptive_scaffold.dart';

/// Route paths of the app. Features navigate with
/// `context.go(AppRoutes.chat)` / `context.push(AppRoutes.noteDetail(id))`
/// and never import pages of other features directly.
abstract final class AppRoutes {
  static const explorer = '/';
  static const chat = '/chat';
  static const setup = '/setup';
  static const newNote = '/new';
  static const settings = '/settings';

  /// Models screen (voice + assistant downloads): last onboarding step
  /// content, also reachable from « Réglages → Modèles ».
  static const models = '/models';

  /// « Pépinière — brouillons à valider » : review of the pending captures.
  static const pepiniere = '/pepiniere';

  /// Prefilled edition of a nursery draft; expects the [InboxItem] as the
  /// navigation `extra` (`context.push(AppRoutes.pepiniereEdit, extra: item)`).
  static const pepiniereEdit = '/pepiniere/edit';

  /// Jalon A: former capture tab, redirects to Explorer with the seed dial
  /// open so existing deep links stay valid.
  static const capture = '/capture';

  /// Jalon A: former graph tab, redirects to Explorer (chantier 2 merges
  /// the constellation into it).
  static const graph = '/graph';

  static String noteDetail(String id) => '/note/$id';

  static String noteEdit(String id) => '/note/$id/edit';
}

/// Paths of the two shell tabs, indexed by shell tab index (0 = Explorer,
/// 1 = Assistant). The visual order — Assistant left of the central seed
/// button, Explorer right — is owned by [AdaptiveScaffold].
const List<String> shellTabPaths = [AppRoutes.explorer, AppRoutes.chat];

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

int _tabIndexFor(String location) =>
    location.startsWith(AppRoutes.chat) ? 1 : 0;

/// Application router: an adaptive « 2 + 1 » shell (Explorer, Assistant,
/// seed dial), and full-screen routes for onboarding, settings and note
/// detail/edition.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.explorer,
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
      path: AppRoutes.models,
      builder: (context, state) => const ModelsPage(),
    ),
    GoRoute(
      path: AppRoutes.pepiniere,
      builder: (context, state) => const PepinierePage(),
      routes: [
        GoRoute(
          path: 'edit',
          // The draft travels as the navigation extra; a deep link without
          // one (restored URL) falls back to the nursery list.
          redirect: (context, state) =>
              state.extra is InboxItem ? null : AppRoutes.pepiniere,
          builder: (context, state) =>
              ZettelEditPage(draftItem: state.extra! as InboxItem),
        ),
      ],
    ),
    // Jalon A redirects: the former tabs stay valid as deep links.
    GoRoute(
      path: AppRoutes.capture,
      redirect: (context, state) => '${AppRoutes.explorer}?semer=1',
    ),
    GoRoute(
      path: AppRoutes.graph,
      redirect: (context, state) => AppRoutes.explorer,
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
      // One shared SyncStatusCubit for the whole shell (AppBar indicator,
      // Explorer pill, rail dot) plus the conflict toast; the offline
      // banner sits above the tab content, under the common AppBar.
      builder: (context, state, child) => SyncShellScope(
        child: AdaptiveScaffold(
          selectedIndex: _tabIndexFor(state.matchedLocation),
          onDestinationSelected: (index) => context.go(shellTabPaths[index]),
          // `/capture` lands here as `/?semer=1`; the scaffold opens the
          // seed dial once per rising edge of this flag.
          openSeedDial: state.uri.queryParameters['semer'] == '1',
          child: SyncOfflineBanner(child: child),
        ),
      ),
      routes: [
        GoRoute(
          path: AppRoutes.explorer,
          builder: (context, state) => const ExplorerPage(),
        ),
        GoRoute(
          path: AppRoutes.chat,
          builder: (context, state) => const AssistantChatPage(),
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
                onPressed: () => context.go(AppRoutes.explorer),
                child: const Text('Retour à l’accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
