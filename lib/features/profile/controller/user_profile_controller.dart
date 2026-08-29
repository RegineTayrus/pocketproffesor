import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import 'user_profile.dart';

/// Loads and persists the user's display name.
class UserProfileController extends Notifier<UserProfile> {
  static const _keyName = 'profile.name';

  @override
  UserProfile build() {
    // SharedPreferences reads are synchronous, so the persisted name can be
    // returned straight from build() - no async gap, no default-state flash.
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(_keyName);
    return UserProfile(
      name: (stored != null && stored.isNotEmpty) ? stored : null,
      isLoaded: true,
    );
  }

  /// Stores a non-empty trimmed name; empty input is ignored.
  Future<void> setName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(name: trimmed);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_keyName, trimmed);
  }
}
