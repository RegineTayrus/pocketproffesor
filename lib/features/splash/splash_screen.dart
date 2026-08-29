import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/providers.dart';
import '../../core/theme/widgets/aurora_background.dart';
import '../../core/theme/widgets/glass_container.dart';

/// Entry screen. Decides between the intro (first launch) and the app.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileControllerProvider);
    final theme = Theme.of(context);

    // Route only once preferences have settled, so a returning user is
    // never misrouted to the intro while the name is still loading.
    if (profile.isLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go(profile.hasName ? '/home' : '/intro');
      });
    }

    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: GlassContainer(
            fillOpacity: 0.08,
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
