import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import 'app_settings.dart';

/// Loads and persists generation settings.
class SettingsController extends Notifier<AppSettings> {
  static const _keyMaxTokens = 'settings.maxTokens';
  static const _keyTemperature = 'settings.temperature';
  static const _keyContextSize = 'settings.contextSize';
  static const _keyReduceTransparency = 'settings.reduceTransparency';

  @override
  AppSettings build() {
    // SharedPreferences reads are synchronous, so persisted values can be
    // returned straight from build() - no async gap, no default-state flash.
    final prefs = ref.read(sharedPreferencesProvider);
    return AppSettings(
      maxTokens: prefs.getInt(_keyMaxTokens) ?? AppSettings.defaults.maxTokens,
      temperature:
          prefs.getDouble(_keyTemperature) ?? AppSettings.defaults.temperature,
      contextSize:
          prefs.getInt(_keyContextSize) ?? AppSettings.defaults.contextSize,
      reduceTransparency:
          prefs.getBool(_keyReduceTransparency) ??
          AppSettings.defaults.reduceTransparency,
    );
  }

  Future<void> setMaxTokens(int value) async {
    state = state.copyWith(maxTokens: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_keyMaxTokens, value);
  }

  Future<void> setTemperature(double value) async {
    state = state.copyWith(temperature: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(_keyTemperature, value);
  }

  Future<void> setContextSize(int value) async {
    state = state.copyWith(contextSize: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_keyContextSize, value);
  }

  Future<void> setReduceTransparency(bool value) async {
    state = state.copyWith(reduceTransparency: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_keyReduceTransparency, value);
  }

  Future<void> resetToDefaults() async {
    await setMaxTokens(AppSettings.defaults.maxTokens);
    await setTemperature(AppSettings.defaults.temperature);
    await setContextSize(AppSettings.defaults.contextSize);
    await setReduceTransparency(AppSettings.defaults.reduceTransparency);
  }
}
