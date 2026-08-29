import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

/// Resolves application file paths and reports model file state.
class FileManager {
  FileManager._();

  static const MethodChannel _storageChannel =
      MethodChannel('pocket_professor/storage');

  static Future<Directory> get _appDocuments async =>
      await getApplicationDocumentsDirectory();

  static Future<Directory> modelDir() async {
    final docs = await _appDocuments;
    return Directory('${docs.path}/${AppConstants.modelDirName}');
  }

  static Future<File> modelFile([String? fileName]) async {
    final dir = await modelDir();
    return File('${dir.path}/${fileName ?? AppConstants.modelFileName}');
  }

  static Future<File> pendingModelFile([String? fileName]) async {
    final file = await modelFile(fileName);
    return File('${file.path}.part');
  }

  static Future<bool> isModelDownloaded() async {
    final file = await modelFile();
    return file.exists();
  }

  static Future<bool> isModelDownloading() async {
    final file = await pendingModelFile();
    return file.exists();
  }

  static Future<int> pendingModelBytes() async {
    final file = await pendingModelFile();
    if (!await file.exists()) return 0;
    return file.length();
  }

  static Future<int> modelSize() async {
    final file = await modelFile();
    if (!await file.exists()) return 0;
    return file.length();
  }

  /// Available free space on the application storage in bytes.
  ///
  /// Uses the native `StatFs` channel on Android; returns 0 when the
  /// platform channel is unavailable (e.g. in unit tests).
  static Future<int> freeSpaceBytes() async {
    try {
      return await _storageChannel.invokeMethod<int>('freeSpaceBytes') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Removes the model file and any partial download.
  static Future<void> deleteModel() async {
    final file = await modelFile();
    final pending = await pendingModelFile();
    if (await file.exists()) await file.delete();
    if (await pending.exists()) await pending.delete();
  }

  static Future<void> ensureModelDir() async {
    final dir = await modelDir();
    await dir.create(recursive: true);
  }
}
