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
      body: Container(
        // BoxDecoration com gradient = equivale ao bg-gradient-to-br do Tailwind
        decoration: const BoxDecoration(
          gradient: AppColors.fundo,
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // mesma marca do menu lateral e do onboarding (文字記 = Mojiki)
              Text(
                '文字記',
                style: TextStyle(
                  fontSize: 64,
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'MOJIKI',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 8,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Aprenda japonês com flashcards',
                style: TextStyle(fontSize: 14, color: Colors.white60),
              ),
              SizedBox(height: 48),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    color: Colors.white70, strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
