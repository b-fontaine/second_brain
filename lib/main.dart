import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_rag_sqlite/flutter_gemma_rag_sqlite.dart';
import 'package:git2dart/git2dart.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/sync/application/sync_orchestrator.dart';
import 'features/zettel/data/repositories/zettel_repository_impl.dart';
import 'features/zettel/domain/repositories/zettel_repository.dart';

/// Bootstraps the app: native libraries first (git, local AI), then
/// dependency injection, then the background sync loop, then the UI.
///
/// Every native initialization is best-effort: on failure the app starts
/// anyway in a degraded mode (no git sync / no local AI) instead of
/// crashing at launch.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // libgit2 must be initialized before ANY repository/remote/credential
  // call (on Android it also extracts the trusted CA roots without which
  // every HTTPS fetch fails).
  try {
    await PlatformSpecific.initialize();
  } catch (error, stackTrace) {
    developer.log(
      'git2dart initialization failed, git sync disabled',
      name: 'bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Registers the on-device inference engine, the embedding backend and
  // the vector store (mandatory since flutter_gemma 1.0: the core package
  // registers no engine by itself).
  try {
    await FlutterGemma.initialize(
      inferenceEngines: const [LiteRtLmEngine()],
      embeddingBackends: const [LiteRtEmbeddingBackend()],
      vectorStore: SqliteVectorStore(),
    );
  } catch (error, stackTrace) {
    developer.log(
      'flutter_gemma initialization failed, local AI disabled',
      name: 'bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
  }

  await configureDependencies();

  // Background git synchronization: opportunistic by design, it must never
  // prevent the app from starting.
  try {
    final orchestrator = getIt<SyncOrchestrator>();
    // Composition-root wiring: after a pull applied remote changes, the
    // zettel data layer re-indexes the vault so lists/backlinks refresh.
    final zettelRepository = getIt<ZettelRepository>();
    if (zettelRepository is ZettelRepositoryImpl) {
      orchestrator.remoteChangesApplied.listen(
        (_) => zettelRepository.notifyExternalChange(),
      );
    }
    orchestrator.start();
  } catch (error, stackTrace) {
    developer.log(
      'SyncOrchestrator failed to start, automatic sync disabled',
      name: 'bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
  }

  runApp(const SecondBrainApp());
}
