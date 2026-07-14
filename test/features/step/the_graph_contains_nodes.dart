import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/graph/presentation/bloc/graph_cubit.dart';
import 'package:second_brain/features/graph/presentation/bloc/graph_state.dart';
import 'package:second_brain/features/graph/presentation/painting/graph_painter.dart';

/// Usage: the graph contains {2} nodes
///
/// Asserts on the [GraphCubit] loaded state (one node per zettel) rather
/// than on canvas pixels.
Future<void> theGraphContainsNodes(WidgetTester tester, num param1) async {
  final canvas = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is GraphPainter,
  );
  expect(canvas, findsOneWidget, reason: 'The graph canvas should be rendered');
  final state = BlocProvider.of<GraphCubit>(tester.element(canvas)).state;
  expect(state, isA<GraphLoaded>());
  expect(
    (state as GraphLoaded).nodes,
    hasLength(param1.toInt()),
    reason: 'The graph should contain one node per zettel of the vault',
  );
}
