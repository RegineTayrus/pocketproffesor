import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_professor/ai/runtime/model_downloader.dart';

void main() {
  // No TestWidgetsFlutterBinding here on purpose: it overrides HttpClient
  // to return 400 for every request, which would block the local server.


  late HttpServer server;
  late Uint8List payload;
  bool supportsRanges = true;

  setUp(() async {
    // Deterministic content so stitched output can be compared exactly.
    payload = Uint8List(256 * 1024);
    for (var i = 0; i < payload.length; i++) {
      payload[i] = i % 251;
    }
    supportsRanges = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      if (!supportsRanges || rangeHeader == null) {
        request.response.statusCode = HttpStatus.ok;
        request.response.contentLength = payload.length;
        request.response.add(payload);
        await request.response.close();
        return;
      }
      final match =
          RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader)!;
      final start = int.parse(match.group(1)!);
      final end = match.group(2)!.isEmpty
          ? payload.length - 1
          : int.parse(match.group(2)!);
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/${payload.length}',
      );
      request.response.contentLength = end - start + 1;
      request.response.add(payload.sublist(start, end + 1));
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  String url() => 'http://127.0.0.1:${server.port}/model.gguf';

  Future<Directory> tempDir() async {
    final dir = await Directory.systemTemp.createTemp('model_dl_test');
    addTearDown(() => dir.delete(recursive: true));
    return dir;
  }

  test('parallel segments stitch into byte-perfect output', () async {
    final file = File('${(await tempDir()).path}/model.gguf');
    final downloader =
        ModelDownloader(url: url(), expectedBytes: payload.length);

    var lastRatio = 0.0;
    final totals = <int>{};
    final result = await downloader.download(
      file: file,
      onProgress: (received, total, progress) {
        totals.add(total);
        lastRatio = progress;
      },
    );

    expect(result.path, file.path);
    expect(await file.length(), payload.length);
    expect(await file.readAsBytes(), equals(payload));
    // Segment part files are consumed by assembly.
    expect(File('${file.path}.part.0').existsSync(), isFalse);
    expect(File('${file.path}.part.3').existsSync(), isFalse);
    expect(totals, everyElement(payload.length));
    expect(lastRatio, 1.0);
  });

  test('falls back to a single stream without range support', () async {
    supportsRanges = false;
    final file = File('${(await tempDir()).path}/model.gguf');
    final downloader =
        ModelDownloader(url: url(), expectedBytes: payload.length);

    await downloader.download(file: file);

    expect(await file.length(), payload.length);
    expect(await file.readAsBytes(), equals(payload));
  });

  test('resumes a partially downloaded segment', () async {
    final file = File('${(await tempDir()).path}/model.gguf');
    // With 4 equal segments of 65536 bytes, segment 1 spans
    // [65536, 131071]; pre-store its first half.
    const segmentStart = 65536;
    final partial = payload.sublist(segmentStart, segmentStart + 32768);
    await File('${file.path}.part.1').writeAsBytes(partial, flush: true);

    final downloader =
        ModelDownloader(url: url(), expectedBytes: payload.length);
    await downloader.download(file: file);

    expect(await file.length(), payload.length);
    expect(await file.readAsBytes(), equals(payload));
  });
}

