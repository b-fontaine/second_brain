import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/serre_tokens.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../bloc/dictation_cubit.dart';
import '../bloc/dictation_state.dart';
import '../bloc/model_status_cubit.dart';
import '../bloc/model_status_state.dart';
import '../bloc/sow_synthesis_cubit.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_suggestions.dart';
import '../widgets/model_status_banner.dart';
import '../widgets/sow_synthesis_listener.dart';

/// RAG chat over the local vault (route `/chat`).
///
/// Mobile first; on wide screens the conversation is centered in a
/// constrained column.
class AssistantChatPage extends StatelessWidget {
  const AssistantChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ChatBloc>()),
        BlocProvider(create: (_) => getIt<ModelStatusCubit>()..check()),
        BlocProvider(create: (_) => getIt<DictationCubit>()),
        BlocProvider(create: (_) => getIt<SowSynthesisCubit>()),
      ],
      child: const _AssistantChatView(),
    );
  }
}

class _AssistantChatView extends StatefulWidget {
  const _AssistantChatView();

  @override
  State<_AssistantChatView> createState() => _AssistantChatViewState();
}

class _AssistantChatViewState extends State<_AssistantChatView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final question = text.trim();
    if (question.isEmpty) return;
    context.read<ChatBloc>().add(ChatQuestionSubmitted(question));
    _controller.clear();
  }

  void _prefill(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _inputFocusNode.requestFocus();
  }

  void _onDictationState(BuildContext context, DictationState state) {
    switch (state) {
      case DictationFinished(:final transcript):
        if (transcript.isNotEmpty) {
          final current = _controller.text.trim();
          _prefill(current.isEmpty ? transcript : '$current $transcript');
        }
        context.read<DictationCubit>().reset();
      case DictationError(:final message):
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        context.read<DictationCubit>().reset();
      case DictationIdle():
      case DictationRecording():
      case DictationTranscribing():
        break;
    }
  }

  String _hintFor(ModelStatusState state) {
    return switch (state) {
      ModelStatusReady() => 'Demander au jardin…',
      ModelStatusUnsupported() => 'Assistant indisponible sur cet appareil',
      ModelStatusDownloading() => 'Téléchargement du modèle en cours…',
      ModelStatusNotInstalled() => 'Téléchargez le modèle pour commencer',
      ModelStatusChecking() || ModelStatusError() => 'Assistant indisponible',
    };
  }

  @override
  Widget build(BuildContext context) {
    // No local AppBar: the AdaptiveScaffold shell already titles the tab.
    return Scaffold(
      body: BlocListener<DictationCubit, DictationState>(
        listener: _onDictationState,
        child: SowSynthesisListener(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    const ModelStatusBanner(),
                    Expanded(
                      child: BlocBuilder<ChatBloc, ChatState>(
                        builder: (context, state) {
                          if (state.messages.isEmpty) {
                            return _EmptyConversation(
                              onAsk: _submit,
                              onPrefill: _prefill,
                            );
                          }
                          return _MessageList(
                            messages: state.messages,
                            generating: state is ChatGenerating,
                          );
                        },
                      ),
                    ),
                    const _DictationPreview(),
                    BlocBuilder<ModelStatusCubit, ModelStatusState>(
                      builder: (context, modelState) {
                        return BlocBuilder<ChatBloc, ChatState>(
                          builder: (context, chatState) {
                            return ChatInputBar(
                              controller: _controller,
                              focusNode: _inputFocusNode,
                              enabled: modelState is ModelStatusReady,
                              sending: chatState is ChatGenerating,
                              hintText: _hintFor(modelState),
                              onSend: _submit,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reversed list of bubbles; index 0 is the newest entry so new
/// messages stay pinned at the bottom without scroll management.
class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.generating});

  final List<ChatMessage> messages;
  final bool generating;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (generating ? 1 : 0);
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (generating && index == 0) return const _GeneratingIndicator();
        final effectiveIndex = generating ? index - 1 : index;
        final message = messages[messages.length - 1 - effectiveIndex];
        return ChatMessageBubble(message: message);
      },
    );
  }
}

class _GeneratingIndicator extends StatelessWidget {
  const _GeneratingIndicator();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SerreTokens>()!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'L’assistant rédige une réponse…',
              style: TextStyle(color: tokens.sub),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.onAsk, required this.onPrefill});

  final ValueChanged<String> onAsk;
  final ValueChanged<String> onPrefill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_alt_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Interrogez votre second cerveau',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'L’assistant répond à partir de vos notes, entièrement '
              'hors ligne, et cite ses sources.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ChatSuggestions(onAsk: onAsk, onPrefill: onPrefill),
          ],
        ),
      ),
    );
  }
}

/// Live transcript preview shown above the input while dictating.
class _DictationPreview extends StatelessWidget {
  const _DictationPreview();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DictationCubit, DictationState>(
      builder: (context, state) {
        final (String? label, String transcript) = switch (state) {
          DictationRecording(:final transcript) => ('En écoute…', transcript),
          DictationTranscribing(:final transcript) => (
            'Transcription en cours…',
            transcript,
          ),
          _ => (null, ''),
        };
        if (label == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.graphic_eq, size: 18, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  transcript.isEmpty ? label : '$label $transcript',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
