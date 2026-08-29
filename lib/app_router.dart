import 'package:go_router/go_router.dart';

import 'features/home/home_screen.dart';
import 'features/intro/presentation/intro_screen.dart';
import 'features/splash/splash_screen.dart';

/// Application navigation.
///
/// Flow: splash (decides) -> intro (first launch, asks for a name)
/// -> home (tabs; the AI model prepares itself in the background).
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/intro',
      builder: (context, state) => const IntroScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
