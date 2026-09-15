import 'package:flutter/material.dart';

// Tela de resultado mostrada ao final de uma sessão de estudo, com a
// porcentagem de acertos/erros. Antes disso só aparecia um SnackBar em
// texto simples no rodapé da tela.
class SessionResultScreen extends StatelessWidget {
  final String deckNome;
  final int acertos;
  final int erros;
  final VoidCallback onEstudarNovamente;
  final VoidCallback onVoltarDecks;

  const SessionResultScreen({
    super.key,
    required this.deckNome,
    required this.acertos,
    required this.erros,
    required this.onEstudarNovamente,
    required this.onVoltarDecks,
  });

  int get _total => acertos + erros;

  double get _percentual => _total == 0 ? 0 : acertos / _total;

  // Cor e mensagem mudam de acordo com o desempenho, pra dar um feedback
  // mais expressivo do que só o número.
  _Desempenho get _desempenho {
    final p = _percentual;
    if (p >= 0.9) {
      return const _Desempenho(
        emoji: '🎉',
        mensagem: 'Excelente!',
        cor: Color(0xFF16A34A),
      );
    }
    if (p >= 0.7) {
      return const _Desempenho(
        emoji: '👏',
        mensagem: 'Muito bom!',
        cor: Color(0xFF4ADE80),
      );
    }
    if (p >= 0.5) {
      return const _Desempenho(
        emoji: '💪',
        mensagem: 'Bom trabalho!',
        cor: Color(0xFFFACC15),
      );
    }
    return const _Desempenho(
      emoji: '📚',
      mensagem: 'Continue praticando!',
      cor: Color(0xFFFB923C),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desempenho = _desempenho;

    return Scaffold(
      body: Container(
        width: double.infinity,
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
                const SizedBox(height: 12),
                const Text(
                  'Sessão concluída!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deckNome,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                Expanded(
                  // SingleChildScrollView: em telas/alturas menores esse
                  // conteúdo (anel + emoji + mensagem + stats) pode não
                  // caber, então rola em vez de estourar (mesmo tipo de
                  // ajuste feito no StudyScreen).
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AnelPercentual(
                          percentual: _percentual,
                          cor: desempenho.cor,
                        ),
                        const SizedBox(height: 20),
                        Text(desempenho.emoji, style: const TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          desempenho.mensagem,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatChip(
                              icon: Icons.check_circle,
                              iconColor: const Color(0xFF4ADE80),
                              label: 'Acertos',
                              value: '$acertos',
                            ),
                            const SizedBox(width: 16),
                            _StatChip(
                              icon: Icons.cancel,
                              iconColor: const Color(0xFFFCA5A5),
                              label: 'Erros',
                              value: '$erros',
                            ),
                          ],
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: onEstudarNovamente,
                        icon: const Icon(Icons.replay),
                        label: const Text(
                          'Estudar novamente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFDC2626),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: onVoltarDecks,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Voltar para decks',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Desempenho {
  final String emoji;
  final String mensagem;
  final Color cor;

  const _Desempenho({
    required this.emoji,
    required this.mensagem,
    required this.cor,
  });
}

// Anel de progresso circular com a porcentagem de acertos no meio. Anima do
// zero até o valor final quando a tela aparece (TweenAnimationBuilder
// dispensa AnimationController/dispose pra uma animação tão simples).
class _AnelPercentual extends StatelessWidget {
  final double percentual;
  final Color cor;

  const _AnelPercentual({required this.percentual, required this.cor});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percentual),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 176,
          height: 176,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 14,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 14,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(cor),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
