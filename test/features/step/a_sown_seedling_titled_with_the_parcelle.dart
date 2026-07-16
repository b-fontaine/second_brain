import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: a sown seedling titled {'Paillage du potager en été'} with the parcelle {'potager'}
///
/// Persists an enriched pending capture in the real inbox, exactly as the
/// sowing intake would (proposed title + one parcelle), then lets the
/// vault-write pulse refresh the Explorer pill.
Future<void> aSownSeedlingTitledWithTheParcelle(
  WidgetTester tester,
  String param1,
  String param2,
) async {
  await worldAddInboxItem(
    'Brouillon semé en pépinière au sujet suivant : $param1. '
    'Détail à relire avant repiquage.',
    title: param1,
    tags: [param2],
  );
  await tester.pumpAndSettle();
}
