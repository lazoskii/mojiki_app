import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/validacao_login.dart';

// Lista "8 caracteres · um número · uma maiúscula" embaixo do campo de senha.
// Cada item fica verde assim que é cumprido, enquanto a pessoa digita.
class RequisitosSenha extends StatelessWidget {
  final TextEditingController controller;
  const RequisitosSenha({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder = redesenha só este pedaço a cada tecla digitada
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, valor, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in requisitosSenha)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    r.ok(valor.text) ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: r.ok(valor.text) ? AppColors.verde : AppColors.textoFraco,
                  ),
                  const SizedBox(width: 6),
                  Text(r.texto,
                      style: TextStyle(
                          fontSize: 12,
                          color: r.ok(valor.text)
                              ? AppColors.verde
                              : AppColors.textoSuave)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
