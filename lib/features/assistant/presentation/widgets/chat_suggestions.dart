import 'package:flutter/material.dart';

/// Starter question sent as-is when its chip is tapped.
const String suggestionSummarizeRecent = 'Résume mes notes récentes';

/// Label of the open-ended starter suggestion.
const String suggestionWhatDoIKnowLabel = 'Que sais-je sur… ?';

/// Prefill inserted in the input field for the open-ended suggestion.
const String suggestionWhatDoIKnowPrefill = 'Que sais-je sur ';

/// Starter suggestion chips shown when the conversation is empty.
class ChatSuggestions extends StatelessWidget {
  const ChatSuggestions({
    super.key,
    required this.onAsk,
    required this.onPrefill,
  });

  /// Sends the question immediately.
  final ValueChanged<String> onAsk;

  /// Puts the text in the input field so the user can complete it.
  final ValueChanged<String> onPrefill;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        ActionChip(
          avatar: const Icon(Icons.history, size: 18),
          label: const Text(suggestionSummarizeRecent),
          onPressed: () => onAsk(suggestionSummarizeRecent),
        ),
        ActionChip(
          avatar: const Icon(Icons.search, size: 18),
          label: const Text(suggestionWhatDoIKnowLabel),
          onPressed: () => onPrefill(suggestionWhatDoIKnowPrefill),
        ),
      ],
    );
  }
}
