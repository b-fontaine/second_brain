import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/core/widgets/vault_markdown_image.dart';
import 'package:second_brain/features/setup/domain/entities/vault_config.dart';
import 'package:second_brain/features/setup/domain/repositories/setup_repository.dart';

class MockSetupRepository extends Mock implements SetupRepository {}

void main() {
  group('vaultAssetRelativePath', () {
    test('accepts vault-relative assets paths', () {
      expect(
        vaultAssetRelativePath(Uri.parse('assets/schema.png')),
        'assets/schema.png',
      );
      expect(
        vaultAssetRelativePath(Uri.parse('assets/sub/photo.jpg')),
        'assets/sub/photo.jpg',
      );
    });

    test('rejects remote and data URIs', () {
      expect(
        vaultAssetRelativePath(Uri.parse('https://attacker.example/b.png')),
        isNull,
      );
      expect(
        vaultAssetRelativePath(Uri.parse('http://attacker.example/b.png')),
        isNull,
      );
      expect(
        vaultAssetRelativePath(Uri.parse('data:image/png;base64,AAAA')),
        isNull,
      );
    });

    test('rejects absolute paths and traversal out of assets/', () {
      expect(vaultAssetRelativePath(Uri.parse('/etc/passwd')), isNull);
      expect(
        vaultAssetRelativePath(Uri.parse('assets/../config.json')),
        isNull,
      );
      expect(vaultAssetRelativePath(Uri.parse('../assets/schema.png')), isNull);
    });

    test('rejects paths outside the assets folder', () {
      expect(vaultAssetRelativePath(Uri.parse('zettel/note.md')), isNull);
      expect(vaultAssetRelativePath(Uri.parse('assets')), isNull);
    });
  });

  group('VaultMarkdownImage', () {
    late MockSetupRepository repository;

    setUp(() {
      repository = MockSetupRepository();
      getIt.registerSingleton<SetupRepository>(repository);
    });

    tearDown(() async {
      await getIt.reset();
    });

    Future<void> pumpImage(WidgetTester tester, Uri uri, {String? alt}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultMarkdownImage(uri: uri, alt: alt),
          ),
        ),
      );
    }

    testWidgets('never builds an Image for a remote URI', (tester) async {
      await pumpImage(
        tester,
        Uri.parse('https://attacker.example/beacon.png?u=victim'),
        alt: 'beacon',
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.text('Image externe non chargée : beacon'), findsOneWidget);
      // The repository is not even consulted for a blocked image.
      verifyZeroInteractions(repository);
    });

    testWidgets('renders a vault assets/ image from the vault directory', (
      tester,
    ) async {
      when(
        () => repository.getConfig(),
      ).thenAnswer((_) async => const Right(VaultConfig(vaultPath: '/vault')));

      await pumpImage(tester, Uri.parse('assets/schema.png'));
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image;
      expect(provider, isA<FileImage>());
      expect(
        (provider as FileImage).file.path,
        endsWith('/vault/assets/schema.png'),
      );
    });

    testWidgets('shows a placeholder when no vault is configured', (
      tester,
    ) async {
      when(
        () => repository.getConfig(),
      ).thenAnswer((_) async => const Right(null));

      await pumpImage(tester, Uri.parse('assets/schema.png'));
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.text('Image introuvable'), findsOneWidget);
    });
  });
}
