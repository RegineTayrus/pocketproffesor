/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Pocket Professor';

  /// Set to true (e.g. `--dart-define=LARGE_MODEL=true`) to download the
  /// smarter 1.5B model instead of the default faster 0.5B one.
  static const bool useLargeModel = bool.fromEnvironment('LARGE_MODEL');

  static const String modelFileName = useLargeModel
      ? 'qwen2.5-1.5b-instruct-q4_k_m.gguf'
      : 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const String modelDownloadUrl = useLargeModel
      ? 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/'
          'qwen2.5-1.5b-instruct-q4_k_m.gguf'
      : 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/'
          'qwen2.5-0.5b-instruct-q4_k_m.gguf';

  /// Exact size of the Q4_K_M model file; used for progress display.
  static const int modelSizeBytes =
      useLargeModel ? 1117320736 : 491400032;

  static const String modelDirName = 'models';

  static const int defaultContextSize = 2048;
  static const int defaultMaxTokens = 128;
  static const double defaultTemperature = 0.7;
}
