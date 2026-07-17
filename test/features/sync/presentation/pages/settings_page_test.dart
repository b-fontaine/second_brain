import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/core/theme/serre_tokens.dart';
import 'package:second_brain/features/sync/domain/entities/sync_status.dart';
import 'package:second_brain/features/sync/presentation/bloc/settings_cubit.dart';
import 'package:second_brain/features/sync/presentation/pages/settings_page.dart';

class MockSettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}

void main() {
  const remoteLoaded = SettingsLoaded(
    remoteUrl: 'https://github.com/user/notes.git',
    hasStoredToken: true,
    syncStatus: SyncStatus(state: SyncState.upToDate),
    vaultPath: '/home/user/second_brain_vault',
    noteCount: 12,
  );

  late MockSettingsCubit cubit;

  setUp(() {
    cubit = MockSettingsCubit();
  });

  Future<void> pumpView(WidgetTester tester, SettingsState state) async {
    whenListen(cubit, const Stream<SettingsState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: const SettingsView(),
        ),
      ),
    );
  }

  group('cards', () {
    testWidgets('shows the four cards for a remote-backed vault', (
      tester,
    ) async {
      await pumpView(tester, remoteLoaded);

      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.byKey(const Key('settings_sync_card')), findsOneWidget);
      expect(find.byKey(const Key('settings_token_card')), findsOneWidget);
      expect(find.byKey(const Key('settings_garden_card')), findsOneWidget);
      expect(find.byKey(const Key('settings_models_card')), findsOneWidget);
      // No conflict on a clean status.
      expect(find.byKey(const Key('settings_conflict_card')), findsNothing);
    });

    testWidgets('hides the token card for a local-only vault', (tester) async {
      await pumpView(
        tester,
        const SettingsLoaded(
          remoteUrl: null,
          hasStoredToken: false,
          syncStatus: SyncStatus(state: SyncState.localOnly),
          vaultPath: '/home/user/second_brain_vault',
          noteCount: 3,
        ),
      );

      expect(find.byKey(const Key('settings_token_card')), findsNothing);
      expect(find.text('Aucun dépôt distant configuré'), findsOneWidget);
      expect(
        find.byKey(const Key('settings_force_sync_button')),
        findsNothing,
      );
    });

    testWidgets('the sync card shows the remote, the status and the manual '
        'sync action', (tester) async {
      await pumpView(tester, remoteLoaded);

      final syncCard = find.byKey(const Key('settings_sync_card'));
      expect(
        find.descendant(
          of: syncCard,
          matching: find.text('https://github.com/user/notes.git'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: syncCard, matching: find.text('Synchronisé')),
        findsOneWidget,
      );

      final forceSync = find.byKey(const Key('settings_force_sync_button'));
      expect(find.descendant(of: syncCard, matching: forceSync), findsOneWidget);
      when(() => cubit.forceSync()).thenAnswer((_) async {});
      await tester.ensureVisible(forceSync);
      await tester.tap(forceSync);
      verify(() => cubit.forceSync()).called(1);
    });

    testWidgets('the garden card shows the vault path and the note count', (
      tester,
    ) async {
      await pumpView(tester, remoteLoaded);

      final gardenCard = find.byKey(const Key('settings_garden_card'));
      expect(
        find.descendant(
          of: gardenCard,
          matching: find.text('/home/user/second_brain_vault'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: gardenCard, matching: find.text('12 notes')),
        findsOneWidget,
      );
    });

    testWidgets('the models card links to the models screen', (tester) async {
      await pumpView(tester, remoteLoaded);

      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('settings_models_button')),
      );
      // Wired to `context.push('/models')`; the navigation itself relies
      // on the real router.
      expect(button.onPressed, isNotNull);
      expect(find.text('Gérer les modèles'), findsOneWidget);
    });
  });

  group('conflict card', () {
    testWidgets('appears amber when the last pull resolved conflicts', (
      tester,
    ) async {
      await pumpView(
        tester,
        const SettingsLoaded(
          remoteUrl: 'https://github.com/user/notes.git',
          hasStoredToken: true,
          syncStatus: SyncStatus(state: SyncState.upToDate, conflictCount: 2),
          vaultPath: '/home/user/second_brain_vault',
          noteCount: 12,
        ),
      );

      final conflictCard = find.byKey(const Key('settings_conflict_card'));
      expect(conflictCard, findsOneWidget);
      expect(
        find.descendant(
          of: conflictCard,
          matching: find.text(SettingsView.conflictCardMessage),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: conflictCard,
          matching: find.text('2 fichiers étaient modifiés des deux côtés'),
        ),
        findsOneWidget,
      );

      // Amber card: the state color comes from the Serre tokens.
      final card = tester.widget<Card>(conflictCard);
      final context = tester.element(conflictCard);
      final tokens = Theme.of(context).extension<SerreTokens>()!;
      expect(card.color, tokens.ambre.withValues(alpha: 0.14));
    });

    testWidgets('stays hidden while the status carries no conflict', (
      tester,
    ) async {
      await pumpView(tester, remoteLoaded);

      expect(find.byKey(const Key('settings_conflict_card')), findsNothing);
      expect(find.text(SettingsView.conflictCardMessage), findsNothing);
    });
  });
}
