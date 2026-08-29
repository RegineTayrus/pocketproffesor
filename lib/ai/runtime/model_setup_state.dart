/// Phases of the background AI preparation.
enum ModelSetupPhase { idle, downloading, preparing, ready, failed }

/// Observable state of the model download + engine load.
class ModelSetupState {
  final ModelSetupPhase phase;

  /// Download progress in bytes; [totalBytes] is 0 until known.
  final int receivedBytes;
  final int totalBytes;

  /// Failure description when [phase] is [ModelSetupPhase.failed].
  final String? error;

  const ModelSetupState({
    this.phase = ModelSetupPhase.idle,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  bool get isReady => phase == ModelSetupPhase.ready;

  ModelSetupState copyWith({
    ModelSetupPhase? phase,
    int? receivedBytes,
    int? totalBytes,
    String? error,
    bool clearError = false,
  }) {
    return ModelSetupState(
      phase: phase ?? this.phase,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
