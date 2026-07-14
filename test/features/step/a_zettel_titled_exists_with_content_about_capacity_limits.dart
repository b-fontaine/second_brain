import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: a zettel titled {'Mémoire de travail'} exists with content about capacity limits
Future<void> aZettelTitledExistsWithContentAboutCapacityLimits(
  WidgetTester tester,
  String param1,
) async {
  await worldCreateZettel(
    param1,
    body:
        'La mémoire de travail a une capacité limitée : environ quatre à '
        'sept éléments peuvent être maintenus simultanément. Ces limites de '
        'capacité contraignent fortement le traitement cognitif.',
    tags: const ['cognition', 'memoire'],
  );
  await tester.pumpAndSettle();
}
