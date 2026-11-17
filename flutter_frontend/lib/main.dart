// Ponto de entrada do app: define as rotas (go_router) e o tema.
//
// Mapa das telas:
//   /                Splash          → decide pra onde ir
//   /onboarding      Onboarding      → só na primeira vez
//   /login           Login           → entrar ou criar conta
//   /recuperar-senha Recuperar senha → código por e-mail
//   /home            aba Decks     ┐
//   /study-session   aba Estudar   ├ dentro do AppShell (barra de baixo)
//   /progress        aba Progresso ┘
//   /study/:id       Estudo de um deck (tela cheia; ?modo= e ?voltar=)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'models/modo_estudo.dart';
import 'screens/app_shell.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/recuperar_senha_screen.dart';
import 'screens/home_screen.dart';
import 'screens/study_screen.dart';
import 'screens/study_session_screen.dart';
import 'screens/progress_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

// telas que abrem sem estar logado (todas as outras pedem login)
const _rotasPublicas = {'/', '/onboarding', '/login', '/recuperar-senha'};

// Equivale ao createBrowserRouter do React Router
final _router = GoRouter(
  initialLocation: '/',
  // guarda de login: roda antes de cada navegação. Sem token, qualquer tela
  // privada (ex.: alguém digitando #/home na URL) vai pro login.
  redirect: (context, state) {
    final publica = _rotasPublicas.contains(state.uri.path);
    if (!AuthService.logado && !publica) return '/login';
    return null; // null = segue pra tela pedida
  },
  routes: [
    GoRoute(path: '/', builder: (context, _) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (context, _) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (context, _) => const LoginScreen()),
    GoRoute(
        path: '/recuperar-senha',
        builder: (context, _) => const RecuperarSenhaScreen()),
    // links antigos da tela de boas-vindas (só pedia o nome) caem no login
    GoRoute(path: '/welcome', redirect: (context, _) => '/login'),
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
        // tryParse: um id inválido na URL (#/study/abc) não derruba o app
        deckId: int.tryParse(state.pathParameters['deckId']!) ?? 0,
        // ?modo=rapida|diaria|intensiva quando vem da tela de Sessão de Estudo
        modo: ModoEstudo.deNome(state.uri.queryParameters['modo']),
        // ?voltar=/study-session quando vem da aba Estudar
        voltarPara: state.uri.queryParameters['voltar'] ?? '/home',
      ),
    ),
  ],
);

Future<void> main() async {
  // necessário pra usar SharedPreferences antes do runApp
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.carregar(); // lê o token salvo (fica logado entre aberturas)

  // backend respondeu 401 (token venceu ou o servidor foi reiniciado):
  // esquece o login e abre a tela de entrar
  AuthService.aoExpirarSessao = () async {
    await AuthService.limpar();
    _router.go('/login');
  };

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
