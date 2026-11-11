// Splash: primeira tela, com a marca. Depois de 2s decide pra onde ir:
// Home (já entrou antes), Onboarding (primeira vez) ou Boas-vindas.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// StatefulWidget = componente com estado (equivale a useState no React)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // initState = roda uma vez quando a tela aparece (equivale a useEffect(fn, []))
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2)); // pausa de 2s no splash

    // shared_preferences = localStorage do Flutter
    final prefs = await SharedPreferences.getInstance();
    final isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!mounted) return; // garante que a tela ainda está na pilha

    if (isAuthenticated) {
      context.go('/home');
    } else if (!hasSeenOnboarding) {
      context.go('/onboarding');
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold = estrutura base de uma tela (fundo, corpo, etc.)
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // marca: círculo vermelho no papel claro (como a bandeira do
            // Japão) com 文字記 (= Mojiki)
            Container(
              width: 132,
              height: 132,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.vermelho,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x40D1283A),
                      blurRadius: 30,
                      offset: Offset(0, 12)),
                ],
              ),
              child: const Text(
                '文字記',
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'MOJIKI',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Aprenda japonês com flashcards',
              style: TextStyle(fontSize: 14, color: AppColors.textoSuave),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
