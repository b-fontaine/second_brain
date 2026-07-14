import 'dart:convert';

import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/features/assistant/domain/services/local_ai_service.dart';

/// Deterministic on-device LLM.
///
/// Scripting:
/// - [modelReady] starts false; the step "the local AI model is available"
///   sets it true. [generate] throws [AiException] while it is false.
/// - Set [onGenerate] to fully script a scenario's completions; when null a
///   deterministic default applies: draft-splitting prompts (system prompt
///   asking for `{"notes":[...]}`) return one clean JSON note per non-empty
///   paragraph of the input, other prompts return a canned French answer
///   quoting the prompt's `[[id]]` citations, so RAG citations survive.
/// - [generateCalls] records every (prompt, systemPrompt) pair.
class FakeLocalAiService implements LocalAiService {
  bool modelReady = false;

  /// Full override of the completion; return the raw model output.
  String Function(String prompt, String? systemPrompt)? onGenerate;

  final List<({String prompt, String? systemPrompt})> generateCalls = [];

  @override
  Future<bool> isModelReady() async => modelReady;

  @override
  Stream<ModelDownloadProgress> installModel() async* {
    yield const ModelDownloadProgress(0.5);
    modelReady = true;
    yield const ModelDownloadProgress(1.0);
  }

  @override
  Future<String> generate(String prompt, {String? systemPrompt}) async {
    generateCalls.add((prompt: prompt, systemPrompt: systemPrompt));
    if (!modelReady) {
      throw const AiException('Modèle IA non installé (fake)');
    }
    final override = onGenerate;
    if (override != null) return override(prompt, systemPrompt);
    if (systemPrompt != null && systemPrompt.contains('"notes"')) {
      return _defaultDraftsJson(prompt);
    }
    return _defaultAnswer(prompt);
  }

  @override
  Stream<String> generateStream(String prompt, {String? systemPrompt}) async* {
    yield await generate(prompt, systemPrompt: systemPrompt);
  }

  @override
  Future<void> dispose() async {}

  /// One atomic note per paragraph: first sentence (or line) as title.
  String _defaultDraftsJson(String rawText) {
    final paragraphs = rawText
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();
    final source = paragraphs.isEmpty ? [rawText.trim()] : paragraphs;
    final notes = [
      for (final paragraph in source)
        {
          'title': _titleFor(paragraph),
          'body': paragraph,
          'tags': ['capture'],
        },
    ];
    return jsonEncode({'notes': notes});
  }

  String _titleFor(String paragraph) {
    final firstLine = paragraph.split('\n').first.trim();
    final sentence = firstLine.split(RegExp(r'(?<=[.!?])\s')).first.trim();
    final cleaned = sentence.replaceFirst(RegExp(r'^#+\s*'), '');
    return cleaned.length <= 60 ? cleaned : '${cleaned.substring(0, 60)}…';
  }

  /// Echoes back every `[[id]]` found in the prompt so the repository's
  /// citation extraction has something real to chew on.
  String _defaultAnswer(String prompt) {
    final ids = RegExp(
      r'\[\[(\d{14})(?:\|[^\]]*)?\]\]',
    ).allMatches(prompt).map((match) => match.group(1)!).toSet();
    final citations = ids.map((id) => '[[$id]]').join(' ');
    return citations.isEmpty
        ? "D'après vos notes, voici la réponse."
        : "D'après vos notes $citations, voici la réponse.";
  }
}
