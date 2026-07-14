import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:second_brain/features/capture/data/services/file_downloader.dart';

// These tests exercise HttpFileDownloader against a loopback HTTP server:
// no widgets binding is initialized, so real (local) sockets are allowed.
void main() {
  late HttpServer server;
  late Directory tempDir;
  late Uri url;
  final payload = List<int>.generate(64 * 1024, (i) => i % 251);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('second_brain_dl_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/missing') {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.add(payload);
      }
      await request.response.close();
    });
    url = Uri.parse('http://127.0.0.1:${server.port}/model.onnx');
  });

  tearDown(() async {
    await server.close(force: true);
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'downloads into the destination through a temporary partial file',
    () async {
      const downloader = HttpFileDownloader();
      final destination = File(p.join(tempDir.path, 'model.onnx'));

      final received = await downloader.download(url, destination).last;

      expect(received, payload.length);
      expect(destination.readAsBytesSync(), payload);
      expect(_partialFiles(tempDir), isEmpty);
    },
  );

  test(
    'concurrent downloads of the same destination do not corrupt the file',
    () async {
      const downloader = HttpFileDownloader();
      final destination = File(p.join(tempDir.path, 'model.onnx'));

      // Before the per-destination serialization, both attempts wrote the
      // same partial file (interleaved bytes) and the second rename threw.
      final results = await Future.wait([
        downloader.download(url, destination).last,
        downloader.download(url, destination).last,
      ]);

      expect(results, everyElement(payload.length));
      expect(destination.readAsBytesSync(), payload);
      expect(_partialFiles(tempDir), isEmpty);
    },
  );

  test('an HTTP error surfaces and leaves no partial file behind', () async {
    const downloader = HttpFileDownloader();
    final missing = Uri.parse('http://127.0.0.1:${server.port}/missing');
    final destination = File(p.join(tempDir.path, 'missing.onnx'));

    await expectLater(
      downloader.download(missing, destination).last,
      throwsA(isA<HttpException>()),
    );

    expect(destination.existsSync(), isFalse);
    expect(_partialFiles(tempDir), isEmpty);
  });
}

List<File> _partialFiles(Directory dir) => dir
    .listSync()
    .whereType<File>()
    .where((file) => p.basename(file.path).contains('.part'))
    .toList();
