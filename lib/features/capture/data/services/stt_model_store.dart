import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/exceptions.dart';
import 'app_directories.dart';
import 'file_downloader.dart';
import 'host_platform.dart';

/// One file of an on-device sherpa-onnx model.
class SttModelFile {
  const SttModelFile({
    required this.name,
    required this.url,
    required this.approxBytes,
  });

  final String name;
  final String url;

  /// Fallback size used for progress weighting when the server does not
  /// announce a Content-Length.
  final int approxBytes;
}

/// A set of files forming a usable sherpa-onnx model.
class SttModelSpec {
  const SttModelSpec({required this.dirName, required this.files});

  final String dirName;
  final List<SttModelFile> files;
}

/// Absolute paths of the streaming zipformer (dictation) model files.
class DictationModelPaths {
  const DictationModelPaths({
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
  });

  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;
}

/// Absolute paths of the whisper (file transcription) model files.
class WhisperModelPaths {
  const WhisperModelPaths({
    required this.encoder,
    required this.decoder,
    required this.tokens,
  });

  final String encoder;
  final String decoder;
  final String tokens;
}

// The GitHub k2-fsa release assets (tag `asr-models`) are tar.bz2 archives,
// but package:archive is not available in this project's dependency tree.
// We therefore download the same files individually from the k2-fsa
// HuggingFace mirrors, which expose them non-archived. Note: the French
// zipformer lives under `shaojieli` (csukuangfj does not mirror it and
// returns 401); every URL below verified live on 2026-07-15.
const _zipformerFrBase =
    'https://huggingface.co/shaojieli/sherpa-onnx-streaming-zipformer-fr-2023-04-14/resolve/main';
const _whisperSmallBase =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main';
const _whisperTinyBase =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main';

const _zipformerFr = SttModelSpec(
  dirName: 'sherpa-onnx-streaming-zipformer-fr-2023-04-14',
  files: [
    SttModelFile(
      name: 'encoder-epoch-29-avg-9-with-averaged-model.int8.onnx',
      url:
          '$_zipformerFrBase/encoder-epoch-29-avg-9-with-averaged-model.int8.onnx',
      approxBytes: 133000000,
    ),
    SttModelFile(
      name: 'decoder-epoch-29-avg-9-with-averaged-model.int8.onnx',
      url:
          '$_zipformerFrBase/decoder-epoch-29-avg-9-with-averaged-model.int8.onnx',
      approxBytes: 1400000,
    ),
    SttModelFile(
      name: 'joiner-epoch-29-avg-9-with-averaged-model.int8.onnx',
      url:
          '$_zipformerFrBase/joiner-epoch-29-avg-9-with-averaged-model.int8.onnx',
      approxBytes: 300000,
    ),
    SttModelFile(
      name: 'tokens.txt',
      url: '$_zipformerFrBase/tokens.txt',
      approxBytes: 5000,
    ),
  ],
);

const _whisperSmall = SttModelSpec(
  dirName: 'sherpa-onnx-whisper-small',
  files: [
    SttModelFile(
      name: 'small-encoder.int8.onnx',
      url: '$_whisperSmallBase/small-encoder.int8.onnx',
      approxBytes: 90000000,
    ),
    SttModelFile(
      name: 'small-decoder.int8.onnx',
      url: '$_whisperSmallBase/small-decoder.int8.onnx',
      approxBytes: 160000000,
    ),
    SttModelFile(
      name: 'small-tokens.txt',
      url: '$_whisperSmallBase/small-tokens.txt',
      approxBytes: 800000,
    ),
  ],
);

const _whisperTiny = SttModelSpec(
  dirName: 'sherpa-onnx-whisper-tiny',
  files: [
    SttModelFile(
      name: 'tiny-encoder.int8.onnx',
      url: '$_whisperTinyBase/tiny-encoder.int8.onnx',
      approxBytes: 13000000,
    ),
    SttModelFile(
      name: 'tiny-decoder.int8.onnx',
      url: '$_whisperTinyBase/tiny-decoder.int8.onnx',
      approxBytes: 43000000,
    ),
    SttModelFile(
      name: 'tiny-tokens.txt',
      url: '$_whisperTinyBase/tiny-tokens.txt',
      approxBytes: 800000,
    ),
  ],
);

/// Manages the on-disk sherpa-onnx STT models: layout under
/// `getApplicationSupportDirectory()/stt`, presence checks, and download
/// with global progress.
///
/// Throws [TranscriptionException] on download errors.
@lazySingleton
class SttModelStore {
  const SttModelStore(this._downloader, this._directories, this._platform);

  final FileDownloader _downloader;
  final AppDirectories _directories;
  final HostPlatform _platform;

  static const _sttFolder = 'stt';

  /// Streaming zipformer FR model used for live dictation.
  SttModelSpec get dictationSpec => _zipformerFr;

  /// Whisper model used for file transcription; `tiny` on mobile to keep
  /// the download small, `small` on desktop for better French quality.
  SttModelSpec get transcriptionSpec =>
      _platform.isMobile ? _whisperTiny : _whisperSmall;

  Future<Directory> _root() async {
    final support = await _directories.applicationSupport();
    return Directory(p.join(support.path, _sttFolder));
  }

  /// True when every file of both models is present and non-empty.
  Future<bool> isInstalled() async {
    final root = await _root();
    for (final spec in [dictationSpec, transcriptionSpec]) {
      for (final file in spec.files) {
        final f = File(p.join(root.path, spec.dirName, file.name));
        if (!f.existsSync() || f.lengthSync() == 0) return false;
      }
    }
    return true;
  }

  /// Downloads the missing model files, emitting global progress 0.0 → 1.0.
  Stream<double> install() async* {
    final root = await _root();
    final pending = <(SttModelFile, File)>[];
    for (final spec in [dictationSpec, transcriptionSpec]) {
      for (final file in spec.files) {
        final destination = File(p.join(root.path, spec.dirName, file.name));
        if (!destination.existsSync() || destination.lengthSync() == 0) {
          pending.add((file, destination));
        }
      }
    }
    if (pending.isEmpty) {
      yield 1.0;
      return;
    }

    try {
      // Resolve real sizes when possible so progress is meaningful.
      final sizes = <int>[];
      for (final (file, _) in pending) {
        int? length;
        try {
          length = await _downloader.contentLength(Uri.parse(file.url));
        } on Exception {
          length = null;
        }
        sizes.add(length ?? file.approxBytes);
      }
      final total = sizes.fold<int>(0, (sum, size) => sum + size);

      var completed = 0;
      for (var i = 0; i < pending.length; i++) {
        final (file, destination) = pending[i];
        await for (final received in _downloader.download(
          Uri.parse(file.url),
          destination,
        )) {
          final capped = received > sizes[i] ? sizes[i] : received;
          yield ((completed + capped) / total).clamp(0.0, 1.0);
        }
        completed += sizes[i];
        yield (completed / total).clamp(0.0, 1.0);
      }
    } on TranscriptionException {
      rethrow;
    } catch (e) {
      throw TranscriptionException(
        'Téléchargement du modèle de reconnaissance vocale impossible : $e',
      );
    }
    yield 1.0;
  }

  Future<DictationModelPaths> dictationPaths() async {
    final root = await _root();
    final dir = p.join(root.path, dictationSpec.dirName);
    return DictationModelPaths(
      encoder: p.join(dir, dictationSpec.files[0].name),
      decoder: p.join(dir, dictationSpec.files[1].name),
      joiner: p.join(dir, dictationSpec.files[2].name),
      tokens: p.join(dir, dictationSpec.files[3].name),
    );
  }

  Future<WhisperModelPaths> whisperPaths() async {
    final root = await _root();
    final spec = transcriptionSpec;
    final dir = p.join(root.path, spec.dirName);
    return WhisperModelPaths(
      encoder: p.join(dir, spec.files[0].name),
      decoder: p.join(dir, spec.files[1].name),
      tokens: p.join(dir, spec.files[2].name),
    );
  }
}
