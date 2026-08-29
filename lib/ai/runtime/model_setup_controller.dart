import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/file_manager.dart';
import '../../core/services/providers.dart';
import 'model_setup_state.dart';

/// Prepares the on-device AI in the background: downloads the model file
/// when it is missing, then loads it into the engine.
///
/// The app stays usable while this runs. Messages sent before the model is
/// ready are persisted immediately and answered once [waitForReady]
/// completes, so no separate download screen is needed.
class ModelSetupController extends Notifier<ModelSetupState> {
  Completer<void>? _completion;

  bool get _isRunning =>
      state.phase == ModelSetupPhase.downloading ||
      state.phase == ModelSetupPhase.preparing;

  @override
  ModelSetupState build() {
    ref.onDispose(() {
      unawaited(ref.read(modelDownloaderProvider).cancel());
    });
    return const ModelSetupState();
  }

  /// Fire-and-forget entry point for the home shell. Failures are surfaced
  /// through the state (phase `failed`) instead of being thrown.
  Future<void> startInBackground() async {
    try {
      await waitForReady();
    } catch (_) {
      // Handled by the UI through the failed phase + retry.
    }
  }

  /// Starts setup if needed and resolves once the model is usable.
  ///
  /// Throws when setup fails; callers decide how to surface that.
  /// Safe to call repeatedly while a run is already in flight.
  Future<void> waitForReady() {
    if (state.isReady) return Future<void>.value();
    if (_isRunning) return _completion!.future;
    return _run();
  }

  /// Retries after a failure, e.g. connection restored mid-download.
  Future<void> retry() => _run();

  Future<void> _run() async {
    final completion = _completion = Completer<void>();
    try {
      final downloaded = await FileManager.isModelDownloaded();
      if (!downloaded) {
        await _download();
      }
      await _prepareEngine();
      state = const ModelSetupState(phase: ModelSetupPhase.ready);
      completion.complete();
    } catch (e) {
      state = ModelSetupState(phase: ModelSetupPhase.failed, error: '$e');
      completion.completeError(e);
    }
  }

  Future<void> _download() async {
    final pendingBytes = await FileManager.pendingModelBytes();
    state = ModelSetupState(
      phase: ModelSetupPhase.downloading,
      receivedBytes: pendingBytes,
      totalBytes: AppConstants.modelSizeBytes,
    );
    final file = await FileManager.modelFile();
    await ref.read(modelDownloaderProvider).download(
          file: file,
          onProgress: (received, total, _) {
            state = state.copyWith(receivedBytes: received, totalBytes: total);
          },
        );
  }

  Future<void> _prepareEngine() async {
    state = state.copyWith(phase: ModelSetupPhase.preparing);
    final contextSize = ref.read(settingsControllerProvider).contextSize;
    await ref.read(llmServiceProvider).ensureLoaded(contextSize: contextSize);
  }
}
