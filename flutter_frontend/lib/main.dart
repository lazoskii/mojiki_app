// Ponto de entrada do app: define as rotas (go_router) e o tema.
//
// Mapa das telas:
//   /             Splash        → decide pra onde ir
//   /onboarding   Onboarding    → só na primeira vez
//   /welcome      Boas-vindas   → pede o nome
//   /home         aba Decks     ┐
//   /study-session aba Estudar  ├ dentro do AppShell (barra de baixo)
//   /progress     aba Progresso ┘
//   /study/:id    Estudo de um deck (tela cheia; ?modo= e ?voltar=)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'models/modo_estudo.dart';
import 'screens/app_shell.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/study_screen.dart';
import 'screens/study_session_screen.dart';
import 'screens/progress_screen.dart';
import 'theme/app_theme.dart';

// Equivale ao createBrowserRouter do React Router
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, _) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (context, _) => const OnboardingScreen()),
    GoRoute(path: '/welcome', builder: (context, _) => const WelcomeScreen()),
    // As 3 telas principais ficam dentro do AppShell, que tem a barra de
    // navegação de baixo (Decks · Estudar · Progresso).
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(localizacao: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, _) => const HomeScreen()),
        GoRoute(
            path: '/study-session',
            builder: (context, _) => const StudySessionScreen()),
        GoRoute(path: '/progress', builder: (context, _) => const ProgressScreen()),
      ],
    ),
    // Tela de estudo fica fora do shell: ocupa a tela toda, com "voltar".
    GoRoute(
      path: '/study/:deckId',
      // pathParameters = equivale ao useParams() do React Router
      builder: (_, state) => StudyScreen(
        deckId: int.parse(state.pathParameters['deckId']!),
        // ?modo=rapida|diaria|intensiva quando vem da tela de Sessão de Estudo
        modo: ModoEstudo.deNome(state.uri.queryParameters['modo']),
        // ?voltar=/study-session quando vem da aba Estudar
        voltarPara: state.uri.queryParameters['voltar'] ?? '/home',
      ),
    ),
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
      theme: criarTemaMojiki(), // ver theme/app_theme.dart
      routerConfig: _router,
    );
  }
}
