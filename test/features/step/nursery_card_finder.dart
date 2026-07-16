import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The nursery card (`Key('pepiniere-card-<id>')`) whose content displays
/// [title]. Shared by the « Repiquer » / « Composter » steps so an action
/// always targets the right card, whatever the list order.
Finder findNurseryCardTitled(String title) {
  return find
      .ancestor(
        of: find.text(title),
        matching: find.byWidgetPredicate((widget) {
          final key = widget.key;
          return widget is Material &&
              key is ValueKey<String> &&
              key.value.startsWith('pepiniere-card-');
        }, description: 'nursery seedling card'),
      )
      .first;
}
