import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/router/app_router.dart';

/// Usage: I open the empty nursery
///
/// Navigates straight to `/pepiniere`: with zero pending capture the
/// Explorer shows no « n semis » pill, so there is nothing to tap — the
/// route itself stays reachable (deep link).
Future<void> iOpenTheEmptyNursery(WidgetTester tester) async {
  unawaited(appRouter.push(AppRoutes.pepiniere));
  await tester.pumpAndSettle();
  expect(
    find.text('Pépinière'),
    findsOneWidget,
    reason: 'The nursery review screen should be displayed',
  );
}
