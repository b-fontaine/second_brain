import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/features/setup/domain/entities/vault_config.dart';
import 'package:second_brain/features/setup/presentation/bloc/setup_bloc.dart';
import 'package:second_brain/features/setup/presentation/pages/setup_page.dart';

class MockSetupBloc extends MockBloc<SetupEvent, SetupState>
    implements SetupBloc {}

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
    testWidgets('shows the welcome header and the form', (tester) async {
      await pumpView(tester, const SetupInitial());

      expect(find.text('Bienvenue dans Second Brain'), findsOneWidget);
      expect(find.text('Configurer la synchronisation'), findsOneWidget);
      expect(find.byKey(const Key('repo_url_field')), findsOneWidget);
      expect(find.byKey(const Key('token_field')), findsOneWidget);
      expect(find.text('Cloner et démarrer'), findsOneWidget);
      expect(find.text('Continuer sans synchronisation'), findsOneWidget);
    });

    testWidgets('the token field is obscured with a PAT helper', (
      tester,
    ) async {
      await pumpView(tester, const SetupInitial());

      final tokenField = tester.widget<TextField>(
        find.byKey(const Key('token_field')),
      );
      expect(tokenField.obscureText, isTrue);
      expect(find.text('PAT GitHub/GitLab'), findsOneWidget);
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

    testWidgets('the skip link dispatches SetupLocalOnlyRequested', (
      tester,
    ) async {
      await pumpView(tester, const SetupInitial());

      await tester.ensureVisible(find.text('Continuer sans synchronisation'));
      await tester.tap(find.text('Continuer sans synchronisation'));

      verify(() => bloc.add(const SetupLocalOnlyRequested())).called(1);
    });
  });

  group('cloning state', () {
    testWidgets('shows a spinner and hides the submit button', (tester) async {
      await pumpView(tester, const SetupCloning());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Clonage du dépôt en cours…'), findsOneWidget);
      expect(find.text('Cloner et démarrer'), findsNothing);
    });
  });

  group('error state', () {
    testWidgets('shows the exact failure message in the error color', (
      tester,
    ) async {
      await pumpView(tester, const SetupError('URL de dépôt invalide'));

      expect(find.text('URL de dépôt invalide'), findsOneWidget);
      final errorText = tester.widget<Text>(
        find.byKey(const Key('setup_error_text')),
      );
      final context = tester.element(find.byKey(const Key('setup_error_text')));
      expect(errorText.style?.color, Theme.of(context).colorScheme.error);
    });

    testWidgets('the form stays usable to retry', (tester) async {
      await pumpView(tester, const SetupError('URL de dépôt invalide'));

      expect(find.text('Cloner et démarrer'), findsOneWidget);
      expect(find.text('Continuer sans synchronisation'), findsOneWidget);
    });
  });

  group('done state', () {
    testWidgets('offers the optional AI model download step', (tester) async {
      await pumpView(
        tester,
        const SetupDone(VaultConfig(vaultPath: '/docs/second_brain_vault')),
      );

      expect(find.text('Assistant IA local (optionnel)'), findsOneWidget);
      expect(find.text('Configurer dans l’assistant…'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
      expect(find.byKey(const Key('repo_url_field')), findsNothing);
    });
  });
}
