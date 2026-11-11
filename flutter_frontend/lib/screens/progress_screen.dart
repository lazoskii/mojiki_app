import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conquista.dart';
import '../models/deck.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_retry.dart';
import '../widgets/menu_perfil.dart';

// Aba "Progresso" (equivale a Progress.tsx do frontend React).
// Os números vêm de dados reais: total de decks/cards do backend, e cards
// estudados/sequência de dias/XP guardados localmente pelo ProgressService.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _loading = true;
  String? _error;
  List<Deck> _decks = [];
  String _userName = 'Estudante';
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
      // GET /decks já traz total_cards de cada deck
      final decks = await ApiService.listarDecks();
      final stats = await ProgressService.obterStats();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _decks = decks;
        _userName = prefs.getString('userName') ?? 'Estudante';
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
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorRetry(message: _error!, onRetry: _carregar)
                : _conteudo(),
      ),
    );
  }

  Widget _conteudo() {
    final totalCards = _decks.fold<int>(0, (s, d) => s + d.totalCards);
    final maiorDeck = _decks.isEmpty
        ? 1
        : _decks.map((d) => d.totalCards).reduce((a, b) => a > b ? a : b);
    final estudados = totalCards == 0 ? 0 : _cardsStudied.clamp(0, totalCards);
    final xpNoNivel = _xp % ProgressService.xpPorNivel;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Progresso',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ),
              BotaoPerfil(nome: _userName),
            ],
          ),
          const SizedBox(height: 20),

          // Nível e XP: card de destaque em vermelho
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.vermelho,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Nível $_nivel',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('$xpNoNivel/${ProgressService.xpPorNivel} XP',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: xpNoNivel / ProgressService.xpPorNivel,
                    minHeight: 10,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '+${ProgressService.xpPorAcerto} XP por acerto · faltam '
                  '${ProgressService.xpPorNivel - xpNoNivel} XP pro nível ${_nivel + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              _StatCard(
                icon: Icons.local_fire_department,
                iconColor: AppColors.laranja,
                label: 'Sequência',
                value: _streak == 1 ? '1 dia' : '$_streak dias',
              ),
              _StatCard(
                icon: Icons.trending_up,
                iconColor: AppColors.verde,
                label: 'Estudados',
                value: '$estudados',
              ),
              _StatCard(
                icon: Icons.style,
                iconColor: const Color(0xFF2563EB),
                label: 'Total de cards',
                value: '$totalCards',
              ),
              _StatCard(
                icon: Icons.folder_copy,
                iconColor: AppColors.amarelo,
                label: 'Decks',
                value: '${_decks.length}',
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Progresso geral',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    Text('$estudados de $totalCards cards',
                        style: const TextStyle(color: AppColors.textoSuave)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: totalCards == 0 ? 0 : estudados / totalCards,
                    minHeight: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('Conquistas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
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

          const Text('Cards por deck',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_decks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Nenhum deck ainda.\nCrie um na aba Decks!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textoSuave)),
            )
          else
            for (final deck in _decks)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: cardDecoration(raio: 14),
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
                                  fontWeight: FontWeight.w700)),
                        ),
                        Text(
                            deck.totalCards == 1
                                ? '1 card'
                                : '${deck.totalCards} cards',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textoSuave)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: maiorDeck == 0 ? 0 : deck.totalCards / maiorDeck,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
        ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: desbloqueada ? AppColors.superficie : const Color(0xFFF1ECEA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: desbloqueada ? const Color(0xFFF2D27A) : AppColors.linha,
          width: desbloqueada ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: desbloqueada
                  ? const Color(0xFFFDF3D7)
                  : AppColors.linha,
              shape: BoxShape.circle,
            ),
            child: Icon(
              desbloqueada ? conquista.icon : Icons.lock_outline,
              color: desbloqueada ? AppColors.amarelo : AppColors.textoSuave,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(conquista.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: desbloqueada ? AppColors.texto : AppColors.textoSuave)),
          const SizedBox(height: 2),
          Text(conquista.descricao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textoSuave, height: 1.3)),
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
      decoration: cardDecoration(raio: 16),
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
                    style: const TextStyle(
                        color: AppColors.textoSuave, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
