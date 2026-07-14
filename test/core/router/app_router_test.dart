import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/router/app_router.dart';
import 'package:second_brain/features/setup/domain/entities/vault_config.dart';
import 'package:second_brain/features/setup/domain/repositories/setup_repository.dart';

class MockSetupRepository extends Mock implements SetupRepository {}

void main() {
  late MockSetupRepository repository;

  setUp(() {
    repository = MockSetupRepository();
    getIt.registerSingleton<SetupRepository>(repository);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('redirectIfNotConfigured', () {
    test('redirects to /setup when no vault is configured', () async {
      when(
        () => repository.getConfig(),
      ).thenAnswer((_) async => const Right(null));

      final location = await redirectIfNotConfigured(AppRoutes.notes);

      expect(location, AppRoutes.setup);
    });

    test('redirects every tab and sub-route while unconfigured', () async {
      when(
        () => repository.getConfig(),
      ).thenAnswer((_) async => const Right(null));

      expect(await redirectIfNotConfigured(AppRoutes.capture), AppRoutes.setup);
      expect(await redirectIfNotConfigured(AppRoutes.chat), AppRoutes.setup);
      expect(await redirectIfNotConfigured(AppRoutes.graph), AppRoutes.setup);
      expect(
        await redirectIfNotConfigured('/note/20260714103000'),
        AppRoutes.setup,
      );
      expect(await redirectIfNotConfigured(AppRoutes.newNote), AppRoutes.setup);
    });

    test('does not redirect once a vault is configured', () async {
      when(() => repository.getConfig()).thenAnswer(
        (_) async => const Right(VaultConfig(vaultPath: '/tmp/vault')),
      );

      expect(await redirectIfNotConfigured(AppRoutes.notes), isNull);
      expect(await redirectIfNotConfigured('/note/20260714103000'), isNull);
    });

    test('never redirects the setup route itself (no redirect loop)', () async {
      final location = await redirectIfNotConfigured(AppRoutes.setup);

      expect(location, isNull);
      // Short-circuits before touching the repository.
      verifyNever(() => repository.getConfig());
    });

    test('treats a config read failure as not configured', () async {
      when(
        () => repository.getConfig(),
      ).thenAnswer((_) async => const Left(VaultFailure('lecture impossible')));

      final location = await redirectIfNotConfigured(AppRoutes.notes);

      expect(location, AppRoutes.setup);
    });
  });

  group('AppRoutes', () {
    test('builds note detail and edit paths from an id', () {
      expect(AppRoutes.noteDetail('20260714103000'), '/note/20260714103000');
      expect(AppRoutes.noteEdit('20260714103000'), '/note/20260714103000/edit');
    });

    test('exposes the four shell tabs in destination order', () {
      expect(shellTabPaths, ['/', '/capture', '/chat', '/graph']);
    });
  });

  group('RouteNotFoundPage', () {
    testWidgets('shows a French message and returns to the home tab', (
      tester,
    ) async {
      // Same wiring as [appRouter]: unmatched locations show the page.
      final router = GoRouter(
        initialLocation: '/emplacement-inconnu',
        errorBuilder: (context, state) => const RouteNotFoundPage(),
        routes: [
          GoRoute(
            path: AppRoutes.notes,
            builder: (context, state) => const Scaffold(body: Text('accueil')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Page introuvable'), findsOneWidget);

      await tester.tap(find.text('Retour à l’accueil'));
      await tester.pumpAndSettle();

      expect(find.text('accueil'), findsOneWidget);
    });
  });
}
