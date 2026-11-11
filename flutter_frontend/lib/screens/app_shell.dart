import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Moldura das 3 telas principais com a barra de navegação de baixo
// (Decks · Estudar · Progresso). Substitui o menu lateral (☰), que
// escondia a navegação atrás de um toque a mais.
class AppShell extends StatelessWidget {
  final Widget child;
  final String localizacao;

  const AppShell({super.key, required this.child, required this.localizacao});

  static const _rotas = ['/home', '/study-session', '/progress'];

  @override
  Widget build(BuildContext context) {
    final atual = _rotas.indexWhere((r) => localizacao.startsWith(r));
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: atual < 0 ? 0 : atual,
        onDestinationSelected: (i) => context.go(_rotas[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Decks',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Estudar',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progresso',
          ),
        ],
      ),
    );
  }
}
