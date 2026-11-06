import 'package:flutter/material.dart';
import '../models/conquista.dart';
import '../models/deck.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/error_retry.dart';

// Tela de progresso do usuário (equivale a Progress.tsx do frontend React).
// Diferente da versão React (que usava números aleatórios de "precisão"
// como mock), aqui os números vêm de dados reais: total de decks/cards
// do backend, e cards estudados/sequência de dias guardados localmente
// pelo ProgressService (o backend ainda não tem uma rota de sessões).
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _loading = true;
  String? _error;
  List<Deck> _decks = [];
  int _cardsStudied = 0;
  int _streak = 0;
  int _xp = 0;
  int _nivel = 1;
  int _totalAcertos = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resumo = await ApiService.listarDecks();
      final decks =
          await Future.wait(resumo.map((d) => ApiService.buscarDeck(d.id)));
      final stats = await ProgressService.obterStats();
      if (!mounted) return;
      setState(() {
        _decks = decks;
        _cardsStudied = stats.cardsStudied;
        _streak = stats.streak;
        _xp = stats.xp;
        _nivel = stats.nivel;
        _totalAcertos = stats.totalAcertos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCards = _decks.fold<int>(0, (sum, d) => sum + d.cards.length);
    final maiorDeck = _decks.isEmpty
        ? 0
        : _decks.map((d) => d.cards.length).reduce((a, b) => a > b ? a : b);
    final maxCardsPorDeck = maiorDeck == 0 ? 1 : maiorDeck;
    final estudadosClamped = totalCards == 0 ? 0 : _cardsStudied.clamp(0, totalCards);
    final progressoGeral = totalCards == 0 ? 0.0 : estudadosClamped / totalCards;

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
              : _error != null
                  ? ErrorRetry(message: _error!, onRetry: _carregar)
                  : Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
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
                              'Progresso',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Nível e XP (gamificação simples: 10 XP por
                          // acerto, sobe de nível a cada 100 XP)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.star,
                                            color: Color(0xFFFACC15), size: 20),
                                        const SizedBox(width: 6),
                                        Text('Nível $_nivel',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    Text(
                                        '${_xp % ProgressService.xpPorNivel}/${ProgressService.xpPorNivel} XP',
                                        style: const TextStyle(
                                            color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: (_xp % ProgressService.xpPorNivel) /
                                        ProgressService.xpPorNivel,
                                    minHeight: 10,
                                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFACC15)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Grid de estatísticas
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.6,
                            children: [
                              _StatCard(
                                icon: Icons.local_fire_department,
                                iconColor: const Color(0xFFFB923C),
                                label: 'Sequência',
                                value: '$_streak dias',
                              ),
                              _StatCard(
                                icon: Icons.trending_up,
                                iconColor: const Color(0xFF4ADE80),
                                label: 'Estudados',
                                value: '$estudadosClamped',
                              ),
                              _StatCard(
                                icon: Icons.style,
                                iconColor: const Color(0xFF60A5FA),
                                label: 'Total de Cards',
                                value: '$totalCards',
                              ),
                              _StatCard(
                                icon: Icons.folder_copy,
                                iconColor: const Color(0xFFFACC15),
                                label: 'Decks',
                                value: '${_decks.length}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Progresso geral
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Progresso Geral',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    Text('$estudadosClamped/$totalCards',
                                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progressoGeral,
                                    minHeight: 10,
                                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFACC15)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          const Text('Conquistas',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.5,
                            children: [
                              for (final c in conquistas)
                                _ConquistaCard(
                                  conquista: c,
                                  desbloqueada: c.desbloqueada(
                                    cardsStudied: _cardsStudied,
                                    streak: _streak,
                                    totalAcertos: _totalAcertos,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          const Text('Cards por Deck',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),

                          if (_decks.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Nenhum deck ainda.\nCrie um na tela Decks!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white60, fontSize: 14),
                                ),
                              ),
                            )
                          else
                            for (final deck in _decks)
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(deck.nome,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                        Text('${deck.cards.length} cards',
                                            style: const TextStyle(
                                                color: Colors.white60, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: deck.cards.length / maxCardsPorDeck,
                                        minHeight: 6,
                                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                            Color(0xFFDC2626)),
                                      ),
                                    ),
                                  ],
                                ),
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

class _ConquistaCard extends StatelessWidget {
  final Conquista conquista;
  final bool desbloqueada;

  const _ConquistaCard({required this.conquista, required this.desbloqueada});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: desbloqueada ? 0.1 : 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: desbloqueada
              ? const Color(0xFFFACC15).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            desbloqueada ? conquista.icon : Icons.lock_outline,
            color: desbloqueada ? const Color(0xFFFACC15) : Colors.white38,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(conquista.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: desbloqueada ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(conquista.descricao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: desbloqueada ? Colors.white60 : Colors.white24,
                  fontSize: 10)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w300)),
        ],
      ),
    );
  }
}
