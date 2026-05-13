import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/study_screen.dart';

// Equivale ao createBrowserRouter do React Router
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, _) => const SplashScreen()),
    GoRoute(path: '/welcome', builder: (context, _) => const WelcomeScreen()),
    GoRoute(path: '/home', builder: (context, _) => const HomeScreen()),
    GoRoute(
      path: '/study/:deckId',
      // pathParameters = equivale ao useParams() do React Router
      builder: (_, state) => StudyScreen(
        deckId: int.parse(state.pathParameters['deckId']!),
      ),
    ),
  ],
);

void main() {
  runApp(const FlashcardApp());
}

class FlashcardApp extends StatelessWidget {
  const FlashcardApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp.router = ponto de entrada do app com navegação
    // equivale ao <RouterProvider router={router} /> do React
    return MaterialApp.router(
      title: 'Japanese Flashcards',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFDC2626)),
      ),
      routerConfig: _router,
    );
  }
}
