import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../bloc/chat_state.dart';
import 'wikilink_markdown.dart';

/// A single chat bubble: plain user text, assistant markdown answer
/// with tappable `[[id]]` citations, or inline error.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatMessageRole.user;

    final Widget content;
    if (message.isError) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.text,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      );
    } else if (isUser) {
      content = Text(
        message.text,
        style: TextStyle(color: scheme.onPrimaryContainer),
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WikilinkMarkdownBody(data: message.text),
          if (message.citedZettels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final id in message.citedZettels)
                  ActionChip(
                    avatar: const Icon(Icons.description_outlined, size: 16),
                    label: Text(id.value),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => context.push('/note/${id.value}'),
                  ),
              ],
            ),
          ],
        ],
      );
    }

    final background = message.isError
        ? scheme.errorContainer
        : isUser
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: content,
      ),
    );
  }
}
