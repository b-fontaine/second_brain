import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/sow_synthesis_cubit.dart';
import '../bloc/sow_synthesis_state.dart';

/// Confirmation SnackBar shown when an assistant synthesis lands in the
/// nursery inbox (« Semer cette synthèse »).
const String synthesisSownMessage = 'Semé en pépinière — brouillon à valider.';

/// Surfaces the outcome of « Semer cette synthèse » as SnackBars
/// (confirmation or failure), then resets the cubit so the next answer
/// can be sown too.
class SowSynthesisListener extends StatelessWidget {
  const SowSynthesisListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SowSynthesisCubit, SowSynthesisState>(
      listener: (context, state) {
        switch (state) {
          case SowSynthesisSown():
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text(synthesisSownMessage)),
              );
            context.read<SowSynthesisCubit>().reset();
          case SowSynthesisFailure(:final message):
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
            context.read<SowSynthesisCubit>().reset();
          case SowSynthesisIdle():
          case SowSynthesisSowing():
            break;
        }
      },
      child: child,
    );
  }
}
