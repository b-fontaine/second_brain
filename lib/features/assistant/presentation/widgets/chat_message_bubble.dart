import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/serre_tokens.dart';
import '../../../zettel/presentation/utils/zettel_maturity.dart';
import '../../domain/entities/assistant_answer.dart';
import '../bloc/chat_state.dart';
import '../bloc/sow_synthesis_cubit.dart';
import 'wikilink_markdown.dart';

/// A single chat bubble, in the Serre palette: user question on a deep
/// green (« arbre ») card, assistant answer on an ivory card with a
/// hairline border, inline error on the error container.
///
/// Assistant answers carry their « Sources » chips (title + maturity
/// badge, tap → note detail), the discreet « Et peut-être » suggestions
/// (retrieved but not cited) and the « Semer cette synthèse » action
/// (requires a [SowSynthesisCubit] above; the chat page provides it).
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<SerreTokens>()!;
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
      // Paper on arbre: light text on the deep green in light mode, dark
      // ink on the lightened green of the « serre de nuit » dark tokens.
      content = Text(message.text, style: TextStyle(color: tokens.paper));
    } else {
      content = _AssistantAnswerContent(message: message);
    }

    final Color background;
    BoxBorder? border;
    if (message.isError) {
      background = scheme.errorContainer;
    } else if (isUser) {
      background = tokens.arbre;
    } else {
      background = tokens.surface;
      border = Border.all(color: tokens.line);
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: background,
          border: border,
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

/// Markdown answer plus its Sources chips, « Et peut-être » suggestions
/// and the « Semer cette synthèse » action.
class _AssistantAnswerContent extends StatelessWidget {
  const _AssistantAnswerContent({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WikilinkMarkdownBody(data: message.text),
        if (message.sources.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Sources',
            style: theme.textTheme.labelSmall?.copyWith(color: tokens.sub),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final source in message.sources) _SourceChip(source: source),
            ],
          ),
        ],
        if (message.related.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Et peut-être — notes proches non citées',
            style: theme.textTheme.labelSmall?.copyWith(color: tokens.sub),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final source in message.related)
                _SourceChip(source: source, subdued: true),
            ],
          ),
        ],
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => context.read<SowSynthesisCubit>().sow(message.text),
          icon: const Icon(Icons.spa_outlined, size: 18),
          label: const Text('Semer cette synthèse'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: tokens.accent,
          ),
        ),
      ],
    );
  }
}

/// One retrieved note: title (id as fallback), maturity badge when the
/// degree is known, tap → note detail. The subdued variant renders the
/// « Et peut-être » suggestions more discreetly (outline only).
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source, this.subdued = false});

  final AssistantSource source;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    final linkCount = source.linkCount;
    return ActionChip(
      avatar: linkCount == null
          ? const Icon(Icons.description_outlined, size: 16)
          : _MaturityBadge(maturity: ZettelMaturity.of(linkCount)),
      label: Text(
        source.label,
        style: subdued
            ? theme.textTheme.bodySmall?.copyWith(color: tokens.sub)
            : null,
      ),
      backgroundColor: subdued ? Colors.transparent : null,
      side: subdued ? BorderSide(color: tokens.line) : null,
      visualDensity: VisualDensity.compact,
      onPressed: () => context.push('/note/${source.id.value}'),
    );
  }
}

/// Small colored dot on the Serre maturity scale (pousse / feuillage /
/// arbre).
class _MaturityBadge extends StatelessWidget {
  const _MaturityBadge({required this.maturity});

  final ZettelMaturity maturity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: maturity.color(context),
      ),
    );
  }
}
