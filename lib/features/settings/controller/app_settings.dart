import '../../../core/constants/app_constants.dart';

/// User-tunable generation and appearance settings.
class AppSettings {
  final int maxTokens;
  final double temperature;
  final int contextSize;

  /// Replaces frosted-glass blur with solid surfaces for readability and
  /// battery life.
  final bool reduceTransparency;

  const AppSettings({
    required this.maxTokens,
    required this.temperature,
    required this.contextSize,
    required this.reduceTransparency,
  });

  static const AppSettings defaults = AppSettings(
    maxTokens: AppConstants.defaultMaxTokens,
    temperature: AppConstants.defaultTemperature,
    contextSize: AppConstants.defaultContextSize,
    reduceTransparency: false,
  );

  AppSettings copyWith({
    int? maxTokens,
    double? temperature,
    int? contextSize,
    bool? reduceTransparency,
  }) {
    return AppSettings(
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      contextSize: contextSize ?? this.contextSize,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    );
  }
}
