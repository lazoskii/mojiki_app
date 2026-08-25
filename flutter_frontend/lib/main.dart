import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/study_screen.dart';
import 'screens/study_session_screen.dart';
import 'screens/progress_screen.dart';

// Equivale ao createBrowserRouter do React Router
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, _) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (context, _) => const OnboardingScreen()),
    GoRoute(path: '/welcome', builder: (context, _) => const WelcomeScreen()),
    GoRoute(path: '/home', builder: (context, _) => const HomeScreen()),
    GoRoute(
      path: '/study/:deckId',
      // pathParameters = equivale ao useParams() do React Router
      builder: (_, state) => StudyScreen(
        deckId: int.parse(state.pathParameters['deckId']!),
      ),
    ),
    GoRoute(path: '/study-session', builder: (context, _) => const StudySessionScreen()),
    GoRoute(path: '/progress', builder: (context, _) => const ProgressScreen()),
  ],
);

void main() {
  runApp(const MojikiApp());
}

class MojikiApp extends StatelessWidget {
  const MojikiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp.router = ponto de entrada do app com navegação
    // equivale ao <RouterProvider router={router} /> do React
    return MaterialApp.router(
      title: 'Mojiki',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFDC2626)),
      ),
      routerConfig: _router,
    );
  }
}
