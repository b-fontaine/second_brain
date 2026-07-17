import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';
import 'package:second_brain/features/capture/domain/usecases/ensure_stt_model.dart';
import 'package:second_brain/features/setup/domain/entities/vault_config.dart';
import 'package:second_brain/features/setup/presentation/bloc/models_install_cubit.dart';
import 'package:second_brain/features/setup/presentation/bloc/setup_bloc.dart';
import 'package:second_brain/features/setup/presentation/pages/setup_page.dart';

class MockSetupBloc extends MockBloc<SetupEvent, SetupState>
    implements SetupBloc {}

class MockTranscriptionService extends Mock implements TranscriptionService {}

class MockEnsureSttModel extends Mock implements EnsureSttModel {}

class MockAssistantRepository extends Mock implements AssistantRepository {}

void main() {
  late MockSetupBloc bloc;

  setUp(() {
    bloc = MockSetupBloc();
  });

  Future<void> pumpView(WidgetTester tester, SetupState state) async {
    whenListen(bloc, const Stream<SetupState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<SetupBloc>.value(
          value: bloc,
          child: const SetupView(),
        ),
      ),
    );
  }

  group('initial state', () {
    testWidgets('shows the welcome header and the two path cards', (
      tester,
    ) async {
      await pumpView(tester, const SetupInitial());

      expect(find.text('Bienvenue dans Second Brain'), findsOneWidget);
      expect(find.text('Configurer la synchronisation'), findsOneWidget);
      // « Nouveau jardin » : local-only vault.
      expect(find.byKey(const Key('setup_local_card')), findsOneWidget);
      expect(find.text('Nouveau jardin'), findsOneWidget);
      expect(find.text('Continuer sans synchronisation'), findsOneWidget);
      // « Reprendre un dépôt git » : remote clone with URL + token.
      expect(find.byKey(const Key('setup_remote_card')), findsOneWidget);
      expect(find.text('Reprendre un dépôt git'), findsOneWidget);
      expect(find.byKey(const Key('repo_url_field')), findsOneWidget);
      expect(find.byKey(const Key('token_field')), findsOneWidget);
      expect(find.text('Cloner et démarrer'), findsOneWidget);
    });

    testWidgets('the fields belong to the remote card, the local button to '
        'the local card', (tester) async {
      await pumpView(tester, const SetupInitial());

      expect(
        find.descendant(
          of: find.byKey(const Key('setup_remote_card')),
          matching: find.byKey(const Key('repo_url_field')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('setup_local_card')),
          matching: find.text('Continuer sans synchronisation'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the token field is obscured with a PAT helper and a '
        'keychain notice', (tester) async {
      await pumpView(tester, const SetupInitial());

      final tokenField = tester.widget<TextField>(
        find.byKey(const Key('token_field')),
      );
      expect(tokenField.obscureText, isTrue);
      expect(find.text('PAT GitHub/GitLab'), findsOneWidget);
      expect(find.textContaining('trousseau système'), findsOneWidget);
    });

    testWidgets('submitting the form dispatches SetupRemoteSubmitted', (
      tester,
    ) async {
      await pumpView(tester, const SetupInitial());

      await tester.enterText(
        find.byKey(const Key('repo_url_field')),
        'https://github.com/user/zettelkasten.git',
      );
      await tester.enterText(
        find.byKey(const Key('token_field')),
        'ghp_token123',
      );
      await tester.ensureVisible(find.text('Cloner et démarrer'));
      await tester.tap(find.text('Cloner et démarrer'));

      verify(
        () => bloc.add(
          const SetupRemoteSubmitted(
            remoteUrl: 'https://github.com/user/zettelkasten.git',
            token: 'ghp_token123',
          ),
        ),
      ).called(1);
    });

    testWidgets('the local card button dispatches SetupLocalOnlyRequested', (
      tester,
    ) async {
      await pumpView(tester, const SetupInitial());

      await tester.ensureVisible(find.text('Continuer sans synchronisation'));
      await tester.tap(find.text('Continuer sans synchronisation'));

      verify(() => bloc.add(const SetupLocalOnlyRequested())).called(1);
    });
  });

  group('cloning state', () {
    testWidgets('shows a spinner and disables both card actions', (
      tester,
    ) async {
      await pumpView(tester, const SetupCloning());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Clonage du dépôt en cours…'), findsOneWidget);
      final clone = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Cloner et démarrer'),
      );
      expect(clone.onPressed, isNull);
      final local = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Continuer sans synchronisation'),
      );
      expect(local.onPressed, isNull);
    });
  });

  group('error state', () {
    testWidgets('shows the invalid-URL message inline under the URL field, '
        'exactly once', (tester) async {
      await pumpView(tester, const SetupError('URL de dépôt invalide'));

      // Rendered as the URL field's errorText, inside the remote card.
      expect(find.text('URL de dépôt invalide'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('setup_remote_card')),
          matching: find.text('URL de dépôt invalide'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('setup_error_text')), findsNothing);
    });

    testWidgets('shows clone/token failures inline in the remote card', (
      tester,
    ) async {
      const message = 'Jeton refusé par le dépôt distant : accès interdit';
      await pumpView(tester, const SetupError(message));

      final errorText = find.byKey(const Key('setup_error_text'));
      expect(errorText, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('setup_remote_card')),
          matching: errorText,
        ),
        findsOneWidget,
      );
      final text = tester.widget<Text>(errorText);
      final context = tester.element(errorText);
      expect(text.style?.color, Theme.of(context).colorScheme.error);
    });

    testWidgets('the form stays usable to retry', (tester) async {
      await pumpView(tester, const SetupError('URL de dépôt invalide'));

      final clone = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Cloner et démarrer'),
      );
      expect(clone.onPressed, isNotNull);
      final local = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Continuer sans synchronisation'),
      );
      expect(local.onPressed, isNotNull);
    });
  });

  group('done state', () {
    late MockTranscriptionService transcription;
    late MockEnsureSttModel ensureSttModel;
    late MockAssistantRepository assistantRepository;

    setUp(() {
      transcription = MockTranscriptionService();
      ensureSttModel = MockEnsureSttModel();
      assistantRepository = MockAssistantRepository();
      when(() => transcription.isReady()).thenAnswer((_) async => false);
      when(
        () => assistantRepository.isReady(),
      ).thenAnswer((_) async => const Right(false));
      when(
        () => assistantRepository.getSelectedModel(),
      ).thenAnswer((_) async => const Right(null));
      // The SetupDone branch resolves the app-lifetime models cubit
      // through getIt, exactly like production.
      getIt.registerLazySingleton<ModelsInstallCubit>(
        () => ModelsInstallCubit(
          transcription,
          ensureSttModel,
          assistantRepository,
          isAssistantSupported: () => true,
        ),
        // Never await a close future from a get_it dispose (FakeAsync-zone
        // deadlock trap, see the BDD harness notes).
        dispose: (cubit) => unawaited(cubit.close()),
      );
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('offers the per-model download step with a skip action', (
      tester,
    ) async {
      await pumpView(
        tester,
        const SetupDone(VaultConfig(vaultPath: '/docs/second_brain_vault')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Votre coffre est prêt'), findsOneWidget);
      expect(find.text('Modèles locaux (optionnels)'), findsOneWidget);
      expect(find.text('Reconnaissance vocale'), findsOneWidget);
      expect(find.text('Assistant local'), findsOneWidget);
      expect(find.byKey(const Key('skip_model_button')), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
      expect(find.byKey(const Key('repo_url_field')), findsNothing);
    });
  });
}
