import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/dictation_cubit.dart';
import '../bloc/dictation_state.dart';

/// Question input row: text field, dictation button and send button.
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.sending,
    required this.hintText,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// False when the model is not ready (the banner explains why).
  final bool enabled;

  /// True while the assistant is generating an answer.
  final bool sending;

  final String hintText;

  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = enabled && !sending;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: canSend ? onSend : null,
                decoration: InputDecoration(
                  hintText: hintText,
                  isDense: true,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _DictationButton(enabled: enabled),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: 'Envoyer',
              onPressed: canSend ? () => onSend(controller.text) : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

/// Microphone button reflecting the dictation state.
class _DictationButton extends StatelessWidget {
  const _DictationButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DictationCubit, DictationState>(
      builder: (context, state) {
        return switch (state) {
          DictationRecording() => IconButton.filledTonal(
            tooltip: 'Arrêter la dictée',
            onPressed: () => context.read<DictationCubit>().stop(),
            icon: Icon(
              Icons.stop_circle_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          DictationTranscribing() => const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          _ => IconButton(
            tooltip: 'Dicter la question',
            onPressed: enabled
                ? () => context.read<DictationCubit>().start()
                : null,
            icon: const Icon(Icons.mic_none),
          ),
        };
      },
    );
  }
}
