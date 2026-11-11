import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Telinha de resultado mostrada ao terminar uma sessão de estudo,
// substituindo o SnackBar simples de "Acertos: X · Erros: Y".
Future<void> mostrarResultadoSessao(
  BuildContext context, {
  required int acertos,
  required int erros,
  required VoidCallback onEstudarNovamente,
  required VoidCallback onVoltar,
}) {
  final total = acertos + erros;
  final percentual = total == 0 ? 0.0 : acertos / total;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.vermelho,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sessão concluída!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              total == 0
                  ? 'Nenhum card respondido'
                  : '${(percentual * 100).round()}% de acerto',
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 15),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.check_circle,
                    color: AppColors.verde,
                    fundo: AppColors.verdeClaro,
                    label: 'Acertos',
                    value: acertos,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.cancel,
                    color: AppColors.vermelhoEscuro,
                    fundo: AppColors.vermelhoClaro,
                    label: 'Erros',
                    value: erros,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: percentual,
                minHeight: 8,
                color: AppColors.verde,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onEstudarNovamente();
                },
                child: const Text('Estudar novamente'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onVoltar();
                },
                child: const Text('Voltar aos decks'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color fundo;
  final String label;
  final int value;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.fundo,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text('$value',
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 13)),
        ],
      ),
    );
  }
}
