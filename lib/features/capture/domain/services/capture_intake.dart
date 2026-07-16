import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/failures.dart';
import '../../../../core/services/clock.dart';
import '../../../assistant/domain/services/local_ai_service.dart';
import '../../../zettel/domain/entities/inbox_item.dart';
import '../../../zettel/domain/entities/zettel_id.dart';
import '../../../zettel/domain/repositories/inbox_repository.dart';
import '../usecases/recognize_screenshot.dart';
import '../usecases/transcribe_audio_file.dart';
import 'clipboard_service.dart';

/// Extensions the audio transcription pipeline accepts.
const List<String> captureAudioExtensions = [
  'wav',
  'm4a',
  'mp3',
  'aac',
  'flac',
  'ogg',
  'opus',
];

/// Extensions the image OCR pipeline accepts.
const List<String> captureImageExtensions = [
  'png',
  'jpg',
  'jpeg',
  'webp',
  'bmp',
  'tiff',
];

/// Plain-text and markdown extensions, read verbatim.
const List<String> captureTextExtensions = ['md', 'txt', 'markdown'];

/// Content family of a capture payload. Decides the extraction pipeline
/// (raw text, OCR, or transcription) and the type chip of the preview
/// screen shown before seeding.
enum SeedKind { text, image, audio }

/// What the user is seeding, before any extraction happened.
sealed class CapturePayload extends Equatable {
  const CapturePayload();

  @override
  List<Object?> get props => const [];
}

/// The system pasteboard content (« Coller ») : text, or an image already
/// written to a temporary file by the clipboard service.
final class ClipboardPayload extends CapturePayload {
  const ClipboardPayload(this.content);

  final ClipboardContent content;

  @override
  List<Object?> get props => [content.text, content.imagePath];
}

/// A user-picked file (« Ajouter un fichier ») ; its kind is detected from
/// the extension.
final class FilePayload extends CapturePayload {
  const FilePayload(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

/// Text extracted upstream of the intake (dictation transcript, assistant
/// synthesis...), tagged with its provenance.
final class TextPayload extends CapturePayload {
  const TextPayload(this.text, {this.source = CaptureType.clipboard});

  final String text;
  final CaptureType source;

  @override
  List<Object?> get props => [text, source];
}

/// A capture analyzed and enriched, shown on the preview screen for edits
/// before being sown into the nursery inbox (« Pépinière — brouillons à
/// valider »).
class SeedDraft extends Equatable {
  const SeedDraft({
    required this.type,
    required this.kind,
    required this.text,
    required this.title,
    this.tags = const [],
    this.assetPath,
  });

  /// Provenance persisted with the inbox item.
  final CaptureType type;

  /// Detected content family (drives the preview type chip).
  final SeedKind kind;

  /// Extracted text — user-editable on the preview screen.
  final String text;

  /// Proposed title — user-editable on the preview screen.
  final String title;

  /// Proposed parcelles (tags) — user-removable on the preview screen.
  final List<String> tags;

  /// Original asset (image, audio file) imported into the vault on sow.
  final String? assetPath;

  SeedDraft copyWith({String? text, String? title, List<String>? tags}) {
    return SeedDraft(
      type: type,
      kind: kind,
      text: text ?? this.text,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      assetPath: assetPath,
    );
  }

  @override
  List<Object?> get props => [type, kind, text, title, tags, assetPath];
}

/// Single entry point of the seeding flow: payload → type detection
/// (mime/extension/pasteboard content) → existing extraction pipeline
/// (OCR for images, transcription for audio, raw markdown/text otherwise)
/// → enriched draft persisted in the inbox nursery.
///
/// The enrichment (proposed title and parcelles) comes from
/// [LocalAiService] when the model is ready and NEVER blocks a seeding:
/// on any AI unavailability or malformed output, the first line of the
/// text becomes the title and no parcelle is proposed (offline-first).
@lazySingleton
class CaptureIntake {
  const CaptureIntake(
    this._recognizeScreenshot,
    this._transcribeAudioFile,
    this._localAiService,
    this._inboxRepository,
    this._clock,
  );

  final RecognizeScreenshot _recognizeScreenshot;
  final TranscribeAudioFile _transcribeAudioFile;
  final LocalAiService _localAiService;
  final InboxRepository _inboxRepository;
  final Clock _clock;

  static const int _titleMaxChars = 80;
  static const int _enrichmentInputMaxChars = 1500;
  static const int _maxProposedTags = 4;

  /// Strict French system prompt: one short title plus up to 4 lowercase
  /// parcelles (tags), as pure JSON.
  static const String enrichmentSystemPrompt = '''
Tu es l'assistant d'un jardin de notes (méthode Zettelkasten).
On te donne le texte brut d'une capture. Propose un titre court et déclaratif en français, et 0 à 4 parcelles (mots-clés en minuscules, sans espaces).
Réponds UNIQUEMENT avec un objet JSON valide, sans aucun texte autour, au format exact :
{"title":"...","tags":["..."]}
Aucune virgule après le dernier élément d'un tableau ou d'un objet.''';

  /// Detected content family, or null when the payload is not ingestible
  /// (empty clipboard, unsupported file extension).
  SeedKind? detectKind(CapturePayload payload) => switch (payload) {
    TextPayload() => SeedKind.text,
    ClipboardPayload(:final content) => _clipboardKind(content),
    FilePayload(:final path) => _extensionKind(path),
  };

  /// Runs detection, extraction and best-effort enrichment; the returned
  /// draft is meant to be reviewed (and edited) before [sow].
  Future<Either<Failure, SeedDraft>> analyze(CapturePayload payload) async {
    final kind = detectKind(payload);
    if (kind == null) return Left(_unsupportedFailure(payload));

    final extracted = await _extract(payload, kind);
    return extracted.fold<Future<Either<Failure, SeedDraft>>>((
      failure,
    ) async {
      return Left(failure);
    }, (extraction) async {
      final text = extraction.text.trim();
      if (text.isEmpty) {
        return const Left(ValidationFailure('Aucun texte à semer'));
      }
      final proposal = await _propose(text);
      return Right(
        SeedDraft(
          type: _typeOf(payload, kind),
          kind: kind,
          text: text,
          title: proposal.title,
          tags: proposal.tags,
          assetPath: extraction.assetPath,
        ),
      );
    });
  }

  /// Persists the (possibly edited) draft as a single enriched inbox item.
  ///
  /// One write only: enrichment happened during [analyze], so the git sync
  /// loop sees exactly one inbox pulse per seeding.
  Future<Either<Failure, InboxItem>> sow(SeedDraft draft) async {
    final text = draft.text.trim();
    if (text.isEmpty) {
      return const Left(ValidationFailure('Aucun texte à semer'));
    }
    final title = draft.title.trim();
    final seen = <String>{};
    final tags = [
      for (final tag in draft.tags)
        if (tag.trim().isNotEmpty && seen.add(tag.trim())) tag.trim(),
    ];
    final now = _clock.now();
    return _inboxRepository.addItem(
      InboxItem(
        id: ZettelId.fromDateTime(now).value,
        type: draft.type,
        rawText: text,
        capturedAt: now,
        assetPath: draft.assetPath,
        title: title.isEmpty ? null : title,
        tags: tags,
      ),
    );
  }

  // --- Detection -------------------------------------------------------------

  static SeedKind? _clipboardKind(ClipboardContent content) {
    final text = content.text;
    if (text != null && text.trim().isNotEmpty) return SeedKind.text;
    if (content.imagePath != null) return SeedKind.image;
    return null;
  }

  static SeedKind? _extensionKind(String path) {
    final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (captureTextExtensions.contains(extension)) return SeedKind.text;
    if (captureImageExtensions.contains(extension)) return SeedKind.image;
    if (captureAudioExtensions.contains(extension)) return SeedKind.audio;
    return null;
  }

  static CaptureType _typeOf(CapturePayload payload, SeedKind kind) =>
      switch (payload) {
        TextPayload(:final source) => source,
        ClipboardPayload() => CaptureType.clipboard,
        FilePayload() => switch (kind) {
          SeedKind.text => CaptureType.file,
          SeedKind.image => CaptureType.screenshot,
          SeedKind.audio => CaptureType.audio,
        },
      };

  static Failure _unsupportedFailure(CapturePayload payload) =>
      switch (payload) {
        ClipboardPayload() => const ValidationFailure(
          'Le presse-papiers est vide',
        ),
        FilePayload(:final path) => ValidationFailure(
          'Format de fichier non pris en charge : '
          '${p.extension(path).isEmpty ? p.basename(path) : p.extension(path)}',
        ),
        TextPayload() => const ValidationFailure('Aucun texte à semer'),
      };

  // --- Extraction ------------------------------------------------------------

  Future<Either<Failure, ({String text, String? assetPath})>> _extract(
    CapturePayload payload,
    SeedKind kind,
  ) async {
    switch (payload) {
      case TextPayload(:final text):
        return Right((text: text, assetPath: null));
      case ClipboardPayload(:final content):
        if (kind == SeedKind.text) {
          return Right((text: content.text ?? '', assetPath: null));
        }
        return _ocr(content.imagePath!);
      case FilePayload(:final path):
        return switch (kind) {
          SeedKind.text => _readTextFile(path),
          SeedKind.image => _ocr(path),
          SeedKind.audio => (await _transcribeAudioFile(
            TranscribeAudioFileParams(path),
          )).map((text) => (text: text, assetPath: path)),
        };
    }
  }

  Future<Either<Failure, ({String text, String? assetPath})>> _ocr(
    String imagePath,
  ) async {
    final result = await _recognizeScreenshot(
      RecognizeScreenshotParams(imagePath),
    );
    return result.map((text) => (text: text, assetPath: imagePath));
  }

  /// Synchronous IO on purpose: real async dart:io reads never complete
  /// inside the FakeAsync zone of widget tests (same rationale as the
  /// test vault datasource), and note files are small.
  Either<Failure, ({String text, String? assetPath})> _readTextFile(
    String path,
  ) {
    try {
      final text = File(path).readAsStringSync();
      return Right((text: text, assetPath: null));
    } on FileSystemException catch (e) {
      return Left(
        ValidationFailure(
          'Lecture du fichier « ${p.basename(path)} » impossible : '
          '${e.message}',
        ),
      );
    }
  }

  // --- Enrichment (best effort, never blocking) -------------------------------

  Future<({String title, List<String> tags})> _propose(String text) async {
    final fallback = (title: _fallbackTitle(text), tags: const <String>[]);
    try {
      if (!await _localAiService.isModelReady()) return fallback;
      final response = await _localAiService.generate(
        _truncate(text, _enrichmentInputMaxChars),
        systemPrompt: enrichmentSystemPrompt,
      );
      return _tryParseProposal(response) ?? fallback;
    } catch (_) {
      // Offline-first: a failing enrichment must never block a seeding.
      return fallback;
    }
  }

  /// Decodes `{"title":"...","tags":["..."]}` from the model output,
  /// tolerating surrounding prose or markdown fences. Null when nothing
  /// usable was recovered (caller falls back).
  ({String title, List<String> tags})? _tryParseProposal(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw.substring(start, end + 1));
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final title = decoded['title'];
    if (title is! String || title.trim().isEmpty) return null;
    final rawTags = decoded['tags'];
    final seen = <String>{};
    final tags = <String>[
      if (rawTags is List)
        for (final tag in rawTags)
          if (tag is String &&
              tag.trim().isNotEmpty &&
              seen.add(tag.trim().toLowerCase()))
            tag.trim().toLowerCase(),
    ];
    return (
      title: _truncate(title.trim(), _titleMaxChars),
      tags: tags.take(_maxProposedTags).toList(),
    );
  }

  /// Offline fallback: first non-empty line, heading marks stripped.
  String _fallbackTitle(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    var title = lines.isEmpty ? 'Semis sans titre' : lines.first;
    title = title.replaceFirst(RegExp(r'^#+\s*'), '');
    return _truncate(title, _titleMaxChars);
  }

  static String _truncate(String text, int maxChars) {
    final trimmed = text.trim();
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars).trimRight()}…';
  }
}
