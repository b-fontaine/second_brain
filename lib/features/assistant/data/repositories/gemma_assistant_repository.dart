import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../zettel/domain/entities/zettel.dart';
import '../../../zettel/domain/entities/zettel_id.dart';
import '../../../zettel/domain/repositories/zettel_repository.dart';
import '../../domain/entities/ai_model_option.dart';
import '../../domain/entities/assistant_answer.dart';
import '../../domain/entities/zettel_draft.dart';
import '../../domain/repositories/ai_model_preferences.dart';
import '../../domain/repositories/assistant_repository.dart';
import '../../domain/services/local_ai_service.dart';
import '../datasources/vault_rag_index.dart';
import '../models/draft_notes_parser.dart';

/// [AssistantRepository] combining the local LLM ([LocalAiService]) with the
/// vault retrieval index ([VaultRagIndex]).
@LazySingleton(as: AssistantRepository)
class GemmaAssistantRepository implements AssistantRepository {
  GemmaAssistantRepository(
    this._localAiService,
    this._ragIndex,
    this._zettelRepository,
    this._modelPreferences,
  );

  final LocalAiService _localAiService;
  final VaultRagIndex _ragIndex;
  final ZettelRepository _zettelRepository;
  final AiModelPreferences _modelPreferences;

  static const int _suggestedLinksPerDraft = 3;
  static const int _contextZettels = 5;
  static const int _contextBodyMaxChars = 800;
  static const int _fallbackTitleMaxChars = 80;

  /// Strict French system prompt: atomic zettel splitting as pure JSON.
  static const String draftSystemPrompt = '''
Tu es un assistant de prise de notes selon la méthode Zettelkasten.
Découpe le texte fourni par l'utilisateur en notes ATOMIQUES : une seule idée par note, avec un corps autonome, compréhensible sans lire les autres notes.
Réponds toujours en français, quelle que soit la langue du texte fourni.
Réponds UNIQUEMENT avec un objet JSON valide, sans aucun texte autour, au format exact :
{"notes":[{"title":"...","body":"...","tags":["..."]}]}
Contraintes :
- "title" : titre court et déclaratif qui exprime l'idée de la note.
- "body" : le contenu de la note en Markdown, reformulé, autonome.
- "tags" : 1 à 4 mots-clés en minuscules, sans espaces.
- Aucune virgule après le dernier élément d'un tableau ou d'un objet.''';

  /// Strict French system prompt: answer only from the provided notes.
  static const String answerSystemPrompt = '''
Tu es l'assistant du Zettelkasten de l'utilisateur.
Réponds UNIQUEMENT à partir des notes fournies dans le contexte, sans inventer d'information.
Cite chaque note utilisée avec son identifiant au format [[id]].
Si les notes fournies ne suffisent pas pour répondre, dis-le clairement.
Réponds en français, en Markdown.''';

  @override
  Future<Either<Failure, bool>> isReady() async {
    try {
      return Right(await _localAiService.isModelReady());
    } on AiException catch (exception) {
      return Left(AiFailure(exception.message));
    } catch (error) {
      return Left(
        AiFailure("Impossible de vérifier l'état du modèle : $error"),
      );
    }
  }

  @override
  Stream<Either<Failure, double>> installModel() async* {
    try {
      await for (final progress in _localAiService.installModel()) {
        yield Right(progress.fraction);
      }
    } on AiException catch (exception) {
      yield Left(AiFailure(exception.message));
    } catch (error) {
      yield Left(AiFailure('Échec du téléchargement du modèle : $error'));
    }
  }

  @override
  Future<Either<Failure, AiModelId?>> getSelectedModel() async {
    try {
      return Right(await _modelPreferences.getSelectedModel());
    } catch (error) {
      return Left(
        AiFailure('Impossible de lire le modèle sélectionné : $error'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> selectModel(AiModelId modelId) async {
    try {
      await _modelPreferences.setSelectedModel(modelId);
      return const Right(unit);
    } catch (error) {
      return Left(
        AiFailure('Impossible d\'enregistrer le modèle sélectionné : $error'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ZettelDraft>>> proposeDrafts({
    required String rawText,
    String? sourceInboxItemId,
  }) async {
    try {
      final firstResponse = await _localAiService.generate(
        rawText,
        systemPrompt: draftSystemPrompt,
      );
      var notes = DraftNotesParser.tryParse(firstResponse);

      if (notes == null) {
        // One correction round-trip, then give up on JSON.
        final retryResponse = await _localAiService.generate(
          _repairPrompt(rawText, firstResponse),
          systemPrompt: draftSystemPrompt,
        );
        notes = DraftNotesParser.tryParse(retryResponse);
      }

      notes ??= [_fallbackNote(rawText)];

      final drafts = <ZettelDraft>[];
      for (final note in notes) {
        final links = await _suggestLinks(note);
        drafts.add(
          ZettelDraft(
            title: note.title,
            body: await _appendSeeAlso(note.body, links),
            tags: note.tags,
            suggestedLinks: links,
            sourceInboxItemId: sourceInboxItemId,
          ),
        );
      }
      return Right(drafts);
    } on AiException catch (exception) {
      return Left(AiFailure(exception.message));
    } catch (error) {
      return Left(AiFailure('Échec de la préparation des brouillons : $error'));
    }
  }

  @override
  Future<Either<Failure, AssistantAnswer>> answerQuestion(
    String question,
  ) async {
    try {
      final hits = await _ragIndex.topK(question, k: _contextZettels);
      if (hits.isEmpty) {
        return const Right(
          AssistantAnswer(
            text:
                "Je n'ai trouvé aucune note pertinente dans votre "
                'Zettelkasten pour répondre à cette question.',
          ),
        );
      }

      final contextIds = <ZettelId>[];
      final titlesById = <String, String>{};
      final contextBlocks = <String>[];
      for (final (id, excerpt) in hits) {
        contextIds.add(id);
        final zettel = await _findZettel(id);
        final title = zettel?.title ?? '';
        titlesById[id.value] = title;
        final body = _truncate(zettel?.body ?? excerpt, _contextBodyMaxChars);
        contextBlocks.add('[[${id.value}]] $title\n$body');
      }

      final prompt =
          'Notes du Zettelkasten :\n\n'
          '${contextBlocks.join('\n\n---\n\n')}\n\n'
          'Question : $question';
      final answer = await _localAiService.generate(
        prompt,
        systemPrompt: answerSystemPrompt,
      );

      // Sources = ids the model actually referenced in its answer, in
      // order of appearance. When it cited nothing explicitly the whole
      // retrieved context stands in: the answer was still built on it.
      final citedIds = Zettel.parseWikiLinks(answer);
      final sourceIds = citedIds.isEmpty ? contextIds : citedIds;
      final sourceKeys = {for (final id in sourceIds) id.value};

      final degrees = await _linkDegrees({
        ...sourceKeys,
        for (final id in contextIds) id.value,
      });

      final sources = <AssistantSource>[];
      for (final id in sourceIds) {
        // Cited ids outside the retrieved context (the model may reference
        // a note quoted inside another note's body) still get a title.
        final title = titlesById[id.value] ?? (await _findZettel(id))?.title;
        sources.add(
          AssistantSource(
            id: id,
            title: title ?? '',
            linkCount: degrees?[id.value],
          ),
        );
      }
      // Retrieved but not cited → the discreet « Et peut-être » section.
      final related = <AssistantSource>[
        for (final id in contextIds)
          if (!sourceKeys.contains(id.value))
            AssistantSource(
              id: id,
              title: titlesById[id.value] ?? '',
              linkCount: degrees?[id.value],
            ),
      ];
      return Right(
        AssistantAnswer(text: answer, sources: sources, related: related),
      );
    } on AiException catch (exception) {
      return Left(AiFailure(exception.message));
    } catch (error) {
      return Left(AiFailure("L'assistant a rencontré une erreur : $error"));
    }
  }

  // --- proposeDrafts helpers ------------------------------------------------

  String _repairPrompt(String rawText, String invalidResponse) {
    return 'Ta réponse précédente ne contenait pas de JSON valide :\n'
        '${_truncate(invalidResponse, 400)}\n\n'
        'Recommence. Réponds UNIQUEMENT avec un objet JSON valide au format '
        '{"notes":[{"title":"...","body":"...","tags":["..."]}]} '
        'pour le texte suivant :\n$rawText';
  }

  /// Last-resort draft: the raw text as a single note, first line as title.
  ParsedDraftNote _fallbackNote(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    var title = lines.isEmpty ? 'Note capturée' : lines.first;
    title = title.replaceFirst(RegExp(r'^#+\s*'), '');
    title = _truncate(title, _fallbackTitleMaxChars);
    return ParsedDraftNote(title: title, body: rawText.trim());
  }

  Future<List<ZettelId>> _suggestLinks(ParsedDraftNote note) async {
    final hits = await _ragIndex.topK(
      '${note.title}\n${note.body}',
      k: _suggestedLinksPerDraft,
    );
    return [for (final (id, _) in hits) id];
  }

  /// Appends one `Voir aussi : [[id|titre]]` line per suggested link.
  Future<String> _appendSeeAlso(String body, List<ZettelId> links) async {
    if (links.isEmpty) return body;
    final buffer = StringBuffer(body.trimRight())..write('\n');
    for (final id in links) {
      final title = (await _findZettel(id))?.title;
      final wikilink = title == null || title.isEmpty
          ? '[[${id.value}]]'
          : '[[${id.value}|$title]]';
      buffer.write('\nVoir aussi : $wikilink');
    }
    return buffer.toString();
  }

  // --- answerQuestion helpers -----------------------------------------------

  /// Undirected link degree of each id in [ids] over the whole vault
  /// (reciprocal links merged, self-links and links to missing notes
  /// ignored — same rules as the Explorer graph). One vault read covers
  /// every surfaced note. Null when the vault could not be read: callers
  /// then hide the maturity badge instead of showing a wrong one.
  Future<Map<String, int>?> _linkDegrees(Set<String> ids) async {
    try {
      final result = await _zettelRepository.getAllZettels();
      return result.fold((_) => null, (all) {
        final live = {for (final zettel in all) zettel.id.value};
        final adjacency = <String, Set<String>>{};
        for (final zettel in all) {
          final source = zettel.id.value;
          for (final target in zettel.outgoingLinks) {
            final targetId = target.value;
            if (targetId == source || !live.contains(targetId)) continue;
            (adjacency[source] ??= <String>{}).add(targetId);
            (adjacency[targetId] ??= <String>{}).add(source);
          }
        }
        return {for (final id in ids) id: adjacency[id]?.length ?? 0};
      });
    } catch (_) {
      return null;
    }
  }

  // --- shared helpers -------------------------------------------------------

  Future<Zettel?> _findZettel(ZettelId id) async {
    final result = await _zettelRepository.getZettelById(id);
    return result.fold<Zettel?>((_) => null, (zettel) => zettel);
  }

  String _truncate(String text, int maxChars) {
    final trimmed = text.trim();
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars).trimRight()}…';
  }
}
