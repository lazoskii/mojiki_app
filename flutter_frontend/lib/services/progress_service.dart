import 'package:shared_preferences/shared_preferences.dart';

// Guarda estatísticas de estudo localmente no aparelho (equivale ao
// "mock data" que a versão React tinha, mas usando dados reais do
// que o usuário efetivamente estudou, já que o backend ainda não
// tem uma rota de StudySession implementada).
class ProgressService {
  static const _kCardsStudied = 'cardsStudied';
  static const _kStreak = 'streakDays';
  static const _kLastStudyDate = 'lastStudyDate'; // formato yyyy-MM-dd
  static const _kXp = 'xp';
  static const _kTotalAcertos = 'totalAcertos';

  // Gamificação simples: cada acerto vale um tanto de XP fixo, e a cada
  // 100 XP o usuário sobe de nível. Sem fórmula complicada de propósito.
  static const xpPorAcerto = 10;
  static const xpPorNivel = 100;

  // Chama toda vez que o usuário vira um flashcard (equivale a 1 revisão)
  static Future<void> registrarCardEstudado() async {
    final prefs = await SharedPreferences.getInstance();
    final total = (prefs.getInt(_kCardsStudied) ?? 0) + 1;
    await prefs.setInt(_kCardsStudied, total);
    await _atualizarStreak(prefs);
  }

  // Chama toda vez que o usuário acerta um card na autoavaliação
  // (Acertei/Errei) — soma XP e conta pra conquista de total de acertos.
  static Future<void> registrarAcerto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kXp, (prefs.getInt(_kXp) ?? 0) + xpPorAcerto);
    await prefs.setInt(
        _kTotalAcertos, (prefs.getInt(_kTotalAcertos) ?? 0) + 1);
  }

  // Último deck aberto — alimenta o atalho "Continuar estudando" da Home.
  static const _kUltimoDeck = 'ultimoDeckId';

  static Future<void> salvarUltimoDeck(int deckId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUltimoDeck, deckId);
  }

  static Future<int?> ultimoDeck() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kUltimoDeck);
  }

  static Future<void> _atualizarStreak(SharedPreferences prefs) async {
    final hoje = _formatarData(DateTime.now());
    final ultimaData = prefs.getString(_kLastStudyDate);

    if (ultimaData == hoje) return; // já estudou hoje, streak não muda

    final ontem = _formatarData(DateTime.now().subtract(const Duration(days: 1)));
    final streakAtual = prefs.getInt(_kStreak) ?? 0;

    // Se estudou ontem, continua a sequência. Senão, começa de novo.
    final novoStreak = (ultimaData == ontem) ? streakAtual + 1 : 1;

    await prefs.setInt(_kStreak, novoStreak);
    await prefs.setString(_kLastStudyDate, hoje);
  }

  static String _formatarData(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<
      ({
        int cardsStudied,
        int streak,
        int xp,
        int nivel,
        int totalAcertos
      })> obterStats() async {
    final prefs = await SharedPreferences.getInstance();
    final xp = prefs.getInt(_kXp) ?? 0;

    // A sequência só vale se o último estudo foi hoje ou ontem. Antes, quem
    // ficava dias sem estudar continuava vendo "3 dias seguidos" até
    // estudar de novo.
    final ultimaData = prefs.getString(_kLastStudyDate);
    final hoje = _formatarData(DateTime.now());
    final ontem =
        _formatarData(DateTime.now().subtract(const Duration(days: 1)));
    final streakValido = ultimaData == hoje || ultimaData == ontem;

    return (
      cardsStudied: prefs.getInt(_kCardsStudied) ?? 0,
      streak: streakValido ? (prefs.getInt(_kStreak) ?? 0) : 0,
      xp: xp,
      nivel: (xp ~/ xpPorNivel) + 1,
      totalAcertos: prefs.getInt(_kTotalAcertos) ?? 0,
    );
  }
}
