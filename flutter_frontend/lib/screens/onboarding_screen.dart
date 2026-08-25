import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Tela de introdução mostrada só na primeira vez que o app abre
// (equivale a Onboarding.tsx do frontend React).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  // AnimationController tocando uma vez = equivale às animações de
  // entrada em cascata (motion.div com delay crescente) do React.
  late final AnimationController _controller;

  static const _kanjis = ['古', '文', '字'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _fadeIn(double start, double end) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  Future<void> _comecar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDC2626), Color(0xFF991B1B), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                // Conteúdo central: kanjis + mini flashcards
                Expanded(
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeIn(0.15, 0.6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final k in _kanjis)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                    k,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 56,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 32),
                          const _MiniFlashcardColumn(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Rodapé
                FadeTransition(
                  opacity: _fadeIn(0.6, 1.0),
                  child: Column(
                    children: [
                      const Text(
                        'Bem-vindo ao Mojiki',
                        style: TextStyle(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Aprenda japonês com flashcards interativos',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _comecar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFDC2626),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Começar',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: i == 1 ? 1 : 0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Mini flashcards que viram sozinhas de tempos em tempos, mostrando
// romaji na frente e hiragana no verso (equivale ao MiniFlashcard do React).
class _MiniFlashcardColumn extends StatelessWidget {
  const _MiniFlashcardColumn();

  @override
  Widget build(BuildContext context) {
    const chars = [
      (romaji: 'ko', hiragana: 'こ'),
      (romaji: 'mo', hiragana: 'も'),
      (romaji: 'ji', hiragana: 'じ'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chars.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _MiniFlashcard(
              romaji: chars[i].romaji,
              hiragana: chars[i].hiragana,
              delay: Duration(milliseconds: 800 + i * 350),
            ),
          ),
      ],
    );
  }
}

class _MiniFlashcard extends StatefulWidget {
  final String romaji;
  final String hiragana;
  final Duration delay;

  const _MiniFlashcard({
    required this.romaji,
    required this.hiragana,
    required this.delay,
  });

  @override
  State<_MiniFlashcard> createState() => _MiniFlashcardState();
}

class _MiniFlashcardState extends State<_MiniFlashcard> {
  bool _flipped = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _flipped = true);
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        setState(() => _flipped = !_flipped);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Container(
        key: ValueKey(_flipped),
        width: 64,
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          gradient: _flipped
              ? const LinearGradient(
                  colors: [Color(0xFFDC2626), Colors.black],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: _flipped ? null : Colors.white,
          border: _flipped ? null : Border.all(color: const Color(0xFFFCA5A5), width: 2),
        ),
        child: Text(
          _flipped ? widget.hiragana : widget.romaji,
          style: TextStyle(
            fontSize: _flipped ? 22 : 16,
            fontWeight: FontWeight.w500,
            color: _flipped ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }
}
