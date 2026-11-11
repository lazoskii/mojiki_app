import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Estado de erro reaproveitado nas telas que carregam dados da API
// (Home, Estudar, Estudo de um deck, Progresso), pra que uma falha de rede
// mostre uma mensagem com botão de tentar de novo em vez de travar no
// spinner pra sempre.
class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.vermelhoClaro, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off,
                  color: AppColors.vermelho, size: 34),
            ),
            const SizedBox(height: 16),
            const Text('Sem conexão',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
