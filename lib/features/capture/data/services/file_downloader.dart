import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';

/// Downloads files over HTTP with byte-level progress reporting.
///
/// Implementations throw raw IO exceptions ([SocketException],
/// [HttpException]...); callers convert them into typed exceptions.
abstract interface class FileDownloader {
  /// Size in bytes announced by the server, or null when unknown.
  Future<int?> contentLength(Uri url);

  /// Downloads [url] into [destination], emitting the cumulative number of
  /// bytes received. The file only appears at [destination] once fully
  /// downloaded (atomic rename of a temporary partial file).
  Stream<int> download(Uri url, File destination);
}

/// [FileDownloader] backed by `dart:io` [HttpClient] (the `http` package is
/// not a direct dependency of this project).
@LazySingleton(as: FileDownloader)
class HttpFileDownloader implements FileDownloader {
  const HttpFileDownloader();

  /// Maximum time to establish a connection and maximum gap between two
  /// received chunks: a connection that stalls without erroring (e.g. a
  /// Wi-Fi switch mid-download) aborts instead of hanging forever.
  static const Duration _idleTimeout = Duration(seconds: 30);

  /// In-flight downloads keyed by destination path: a concurrent request
  /// for the same file waits for the first attempt instead of writing the
  /// same partial file (which would corrupt the destination).
  static final Map<String, Future<void>> _inFlight = {};

  /// Disambiguates partial-file names of attempts started within the same
  /// microsecond.
  static int _attemptCounter = 0;

  @override
  Future<int?> contentLength(Uri url) async {
    final client = HttpClient()..connectionTimeout = _idleTimeout;
    try {
      final request = await client.headUrl(url);
      request.followRedirects = true;
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode >= 400) return null;
      return response.contentLength > 0 ? response.contentLength : null;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Stream<int> download(Uri url, File destination) async* {
    // Serialize concurrent downloads of the same destination.
    while (true) {
      final pending = _inFlight[destination.path];
      if (pending == null) break;
      try {
        await pending;
      } catch (_) {
        // The other attempt failed: this one retries below.
      }
    }
    if (destination.existsSync() && destination.lengthSync() > 0) {
      // Another caller completed this download while we were waiting.
      yield destination.lengthSync();
      return;
    }
    final completer = Completer<void>();
    _inFlight[destination.path] = completer.future;
    try {
      yield* _download(url, destination);
    } finally {
      _inFlight.remove(destination.path);
      completer.complete();
    }
  }

  Stream<int> _download(Uri url, File destination) async* {
    final client = HttpClient()..connectionTimeout = _idleTimeout;
    // Unique partial file per attempt: two attempts can never interleave
    // writes into the same file.
    final part = File(
      '${destination.path}.part-'
      '${DateTime.now().microsecondsSinceEpoch}-${_attemptCounter++}',
    );
    IOSink? sink;
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException(
          'Unexpected status ${response.statusCode}',
          uri: url,
        );
      }
      await part.parent.create(recursive: true);
      sink = part.openWrite();
      var received = 0;
      await for (final chunk in response.timeout(_idleTimeout)) {
        sink.add(chunk);
        received += chunk.length;
        yield received;
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (destination.existsSync()) destination.deleteSync();
      part.renameSync(destination.path);
    } finally {
      await sink?.close();
      client.close(force: true);
      // Failed or cancelled attempt: never leave a stale partial file.
      try {
        if (part.existsSync()) part.deleteSync();
      } catch (_) {}
    }
  }
}
