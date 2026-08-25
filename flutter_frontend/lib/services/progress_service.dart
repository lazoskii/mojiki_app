import 'package:shared_preferences/shared_preferences.dart';

// Guarda estatísticas de estudo localmente no aparelho (equivale ao
// "mock data" que a versão React tinha, mas usando dados reais do
// que o usuário efetivamente estudou, já que o backend ainda não
// tem uma rota de StudySession implementada).
class ProgressService {
  static const _kCardsStudied = 'cardsStudied';
  static const _kStreak = 'streakDays';
  static const _kLastStudyDate = 'lastStudyDate'; // formato yyyy-MM-dd

  // Chama toda vez que o usuário vira um flashcard (equivale a 1 revisão)
  static Future<void> registrarCardEstudado() async {
    final prefs = await SharedPreferences.getInstance();
    final total = (prefs.getInt(_kCardsStudied) ?? 0) + 1;
    await prefs.setInt(_kCardsStudied, total);
    await _atualizarStreak(prefs);
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

  static Future<({int cardsStudied, int streak})> obterStats() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      cardsStudied: prefs.getInt(_kCardsStudied) ?? 0,
      streak: prefs.getInt(_kStreak) ?? 0,
    );
  }
}
