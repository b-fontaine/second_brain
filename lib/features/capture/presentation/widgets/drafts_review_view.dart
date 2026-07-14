import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/capture_bloc.dart';
import 'draft_card.dart';

/// Review of the assistant's proposed drafts: edit, accept one by one,
/// accept everything, or reject.
class DraftsReviewView extends StatelessWidget {
  const DraftsReviewView({super.key, required this.state});

  final CaptureDraftsReview state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<CaptureBloc>();
    final count = state.drafts.length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                count > 1
                    ? '$count notes proposées — vérifiez, modifiez puis '
                          'acceptez.'
                    : '1 note proposée — vérifiez, modifiez puis acceptez.',
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  state.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: state.drafts.length,
                itemBuilder: (context, index) => DraftCard(
                  key: ValueKey('draft-$index'),
                  index: index,
                  draft: state.drafts[index],
                  enabled: !state.accepting,
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: state.accepting
                            ? null
                            : () => bloc.add(const CaptureAcceptAllRequested()),
                        icon: state.accepting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.done_all),
                        label: const Text('Tout accepter'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: state.accepting
                          ? null
                          : () => bloc.add(const CaptureDraftsRejected()),
                      child: const Text('Rejeter'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
