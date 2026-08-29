import 'dart:async';
import 'dart:io';

import '../../core/constants/app_constants.dart';
import '../../core/services/file_manager.dart';

/// Downloads the GGUF model with resume support and progress reporting.
///
/// When the server supports HTTP range requests the file is fetched as
/// [_segmentCount] parallel segments for speed; otherwise it falls back to
/// a single stream. Segments live in `<file>.part.<i>` files so interrupted
/// downloads resume where they stopped, and are concatenated into [file]
/// once all of them are complete.
class ModelDownloader {
  static const int _segmentCount = 4;

  final String url;
  final int expectedBytes;

  final List<HttpClient> _clients = [];
  final List<HttpClientRequest> _requests = [];
  bool _cancelled = false;

  ModelDownloader({
    this.url = AppConstants.modelDownloadUrl,
    this.expectedBytes = AppConstants.modelSizeBytes,
  });

  /// Downloads the model to [file]. Returns the final file when complete.
  ///
  /// [onProgress] receives (receivedBytes, totalBytes, progress01).
  /// Throws [ModelDownloadException] on failure; throws [StateError] when
  /// cancelled via [cancel].
  Future<File> download({
    required File file,
    void Function(int received, int total, double progress)? onProgress,
  }) async {
    _cancelled = false;
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final available = await FileManager.freeSpaceBytes();
    if (available > 0 && available < expectedBytes) {
      throw ModelDownloadException(
        'Not enough free space. Need ~'
        '${(expectedBytes / (1024 * 1024)).toStringAsFixed(0)} MB, '
        'but only ${(available / (1024 * 1024)).toStringAsFixed(0)} MB free.',
      );
    }

    final probe = await _probeRangeSupport();
    if (probe == null || probe.totalBytes < _segmentCount) {
      return _downloadSingleStream(file, onProgress);
    }
    final total = probe.totalBytes;

    // A stale partial from the old single-stream layout cannot be resumed
    // into the segmented one.
    final legacyPart = File('${file.path}.part');
    if (await legacyPart.exists()) {
      await legacyPart.delete();
    }

    final ranges = _segmentBoundaries(total);
    final parts = <File>[
      for (var i = 0; i < ranges.length; i++) File('${file.path}.part.$i'),
    ];

    // Resume state: bytes already stored per segment. An oversized segment
    // file is corrupt and restarts from zero.
    final received = <int>[];
    for (var i = 0; i < ranges.length; i++) {
      final length = ranges[i].end - ranges[i].start + 1;
      final have = await parts[i].exists() ? await parts[i].length() : 0;
      received.add(have > length ? 0 : have);
    }

    var lastReport = DateTime.fromMillisecondsSinceEpoch(0);
    void report({bool force = false}) {
      if (onProgress == null) return;
      final now = DateTime.now();
      if (!force &&
          now.difference(lastReport) < const Duration(milliseconds: 100)) {
        return;
      }
      lastReport = now;
      final sum = received.fold<int>(0, (a, b) => a + b);
      onProgress(sum, total, total == 0 ? 0 : sum / total);
    }

    report(force: true);

    final allComplete = <bool>[
      for (var i = 0; i < ranges.length; i++)
        received[i] == ranges[i].end - ranges[i].start + 1,
    ];

    if (!allComplete.every((done) => done)) {
      Object? failure;
      Future<void> worker(int index) async {
        try {
          await _downloadSegment(
            ranges[index],
            parts[index],
            received,
            index,
            report,
          );
        } catch (e) {
          failure ??= e;
          // Stop the sibling segments promptly; their errors are discarded.
          await cancel();
        }
      }

      await Future.wait([
        for (var i = 0; i < ranges.length; i++)
          if (!allComplete[i]) worker(i),
      ]);
      if (failure != null) throw failure!;
    }

    report(force: true);
    return _assemble(file, parts);
  }

  /// Cancels an in-flight download. Partial segment files are kept so the
  /// download can resume later.
  Future<void> cancel() async {
    _cancelled = true;
    final requests = List.of(_requests);
    _requests.clear();
    for (final request in requests) {
      request.abort(StateError('cancelled'));
    }
    final clients = List.of(_clients);
    _clients.clear();
    for (final client in clients) {
      client.close(force: true);
    }
  }

  /// Ranged GET for the first byte only; reveals whether the server honors
  /// ranges and the real total size behind redirects. Returns null when
  /// ranges are unsupported or the probe fails.
  Future<({int totalBytes})?> _probeRangeSupport() async {
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      final request = await client.openUrl('GET', Uri.parse(url));
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final response = await request.close();
      if (response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>();
        return null;
      }
      final contentRange =
          response.headers.value(HttpHeaders.contentRangeHeader);
      await response.drain<void>();
      // Format: "bytes 0-0/TOTAL".
      final match =
          RegExp(r'bytes\s+\d+-\d+/(\d+)').firstMatch(contentRange ?? '');
      if (match == null) return null;
      return (totalBytes: int.parse(match.group(1)!));
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  List<({int start, int end})> _segmentBoundaries(int total) {
    final base = total ~/ _segmentCount;
    return [
      for (var i = 0; i < _segmentCount; i++)
        (
          start: i * base,
          end: i == _segmentCount - 1 ? total - 1 : (i + 1) * base - 1,
        ),
    ];
  }

  Future<void> _downloadSegment(
    ({int start, int end}) range,
    File partFile,
    List<int> received,
    int index,
    void Function() report,
  ) async {
    final segmentLength = range.end - range.start + 1;
    var have = await partFile.exists() ? await partFile.length() : 0;
    if (have > segmentLength) {
      await partFile.delete();
      have = 0;
    }
    if (have == segmentLength || _cancelled) return;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    _clients.add(client);
    HttpClientRequest? request;
    IOSink? sink;
    try {
      request = await client.openUrl('GET', Uri.parse(url));
      _requests.add(request);
      request.headers.set(
        HttpHeaders.rangeHeader,
        'bytes=${range.start + have}-${range.end}',
      );
      final response = await request.close();

      // 200 here would mean the server ignored the range and is streaming
      // the whole body, which would corrupt the segment.
      if (response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>();
        throw ModelDownloadException(
          'Download failed (HTTP ${response.statusCode}).',
        );
      }

      sink = partFile.openWrite(mode: FileMode.append);
      await for (final chunk in response) {
        if (_cancelled) {
          throw StateError('Download cancelled.');
        }
        sink.add(chunk);
        have += chunk.length;
        received[index] = have;
        report();
      }
      await sink.flush();
      if (have != segmentLength) {
        throw ModelDownloadException(
          'Connection closed early ($have of $segmentLength bytes).',
        );
      }
    } finally {
      await sink?.close();
      _requests.remove(request);
      _clients.remove(client);
      client.close(force: true);
    }
  }

  Future<File> _assemble(File file, List<File> parts) async {
    final sink = file.openWrite();
    try {
      for (final part in parts) {
        await for (final chunk in part.openRead()) {
          sink.add(chunk);
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    for (final part in parts) {
      await part.delete();
    }
    return file;
  }

  /// Single-connection fallback mirroring the pre-segmentation behavior,
  /// including `.part` resume.
  Future<File> _downloadSingleStream(
    File file,
    void Function(int received, int total, double progress)? onProgress,
  ) async {
    final partFile = File('${file.path}.part');
    final existing = await partFile.exists() ? await partFile.length() : 0;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    _clients.add(client);
    IOSink? sink;
    try {
      final request = await client.openUrl('GET', Uri.parse(url));
      _requests.add(request);

      if (existing > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
      }

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>();
        throw ModelDownloadException(
          'Download failed (HTTP ${response.statusCode}).',
        );
      }

      final total = expectedBytes;
      var receivedBytes = existing;
      sink = partFile.openWrite(mode: FileMode.append);

      await for (final chunk in response) {
        if (_cancelled) {
          throw StateError('Download cancelled.');
        }
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(receivedBytes, total, receivedBytes / total);
      }
      await sink.flush();
      // Close before renaming: on Windows an open handle blocks the rename.
      await sink.close();
      sink = null;

      if (_cancelled) {
        throw StateError('Download cancelled.');
      }

      await partFile.rename(file.path);
      return file;
    } finally {
      await sink?.close();
      _requests.clear();
      _clients.remove(client);
      client.close(force: true);
    }
  }
}

class ModelDownloadException implements Exception {
  final String message;

  const ModelDownloadException(this.message);

  @override
  String toString() => message;
}
