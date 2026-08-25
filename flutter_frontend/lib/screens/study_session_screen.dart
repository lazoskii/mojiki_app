import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/deck.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

// Tela de seleção de modo de estudo + acesso rápido aos decks
// (equivale a StudySession.tsx do frontend React).
class StudySessionScreen extends StatefulWidget {
  const StudySessionScreen({super.key});

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  List<Deck> _decks = [];
  bool _loading = true;

  static const _studyModes = [
    (
      icon: Icons.flash_on,
      title: 'Sessão Rápida',
      description: '5 minutos de prática',
      duration: '5 min',
      colors: [Color(0xFFEAB308), Color(0xFFC2410C)],
    ),
    (
      icon: Icons.track_changes,
      title: 'Prática Diária',
      description: '15 minutos recomendados',
      duration: '15 min',
      colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
    ),
    (
      icon: Icons.access_time,
      title: 'Sessão Intensiva',
      description: '30 minutos focados',
      duration: '30 min',
      colors: [Color(0xFF9333EA), Color(0xFF7F1D1D)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _carregarDecks();
  }

  Future<void> _carregarDecks() async {
    final resumo = await ApiService.listarDecks();
    // /decks não traz os cards de cada deck (só /decks/{id} traz), então
    // buscamos o detalhe de cada um para saber a quantidade de cards.
    final decks = await Future.wait(resumo.map((d) => ApiService.buscarDeck(d.id)));
    if (!mounted) return;
    setState(() {
      _decks = decks;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDC2626), Color(0xFF991B1B), Colors.black],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                      child: Row(
                        children: [
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Sessão de Estudo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 48), // equilibra o ícone do menu
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'Escolha seu modo de estudo',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final mode in _studyModes)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: mode.colors,
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(mode.icon, color: Colors.white, size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(mode.title,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(mode.description,
                                            style: const TextStyle(
                                                color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(mode.duration,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          const Text(
                            'Acesso Rápido',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          _decks.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'Nenhum deck ainda.\nCrie um na tela Decks!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white60, fontSize: 14),
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.3,
                                  ),
                                  itemCount: _decks.length,
                                  itemBuilder: (context, index) {
                                    final deck = _decks[index];
                                    return GestureDetector(
                                      onTap: () => context.go('/study/${deck.id}'),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.2)),
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(deck.nome,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 4),
                                            Text('${deck.cards.length} cards',
                                                style: const TextStyle(
                                                    color: Colors.white60, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
