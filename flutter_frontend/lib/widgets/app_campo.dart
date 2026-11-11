import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Caixa de texto padrão do app: rótulo EM CIMA, campo de 52 px, texto de
// ajuda embaixo e, com erro, ícone + mensagem (num app vermelho, só a cor
// vermelha não chama atenção de que algo deu errado).
//
// Funciona dentro de um Form (usa `validator`) e também aceita um erro
// vindo de fora, ex.: a mensagem do backend (`erroExterno`).
class AppCampo extends StatelessWidget {
  final TextEditingController controller;
  final String rotulo;
  final String? dica;
  final String? ajuda;
  final String? erroExterno;
  final String? Function(String texto)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;

  const AppCampo({
    super.key,
    required this.controller,
    required this.rotulo,
    this.dica,
    this.ajuda,
    this.erroExterno,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      // lê o controller na hora de validar, assim nunca fica desatualizado
      validator: validator == null ? null : (_) => validator!(controller.text),
      builder: (estado) {
        final erro = estado.errorText ?? erroExterno;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(rotulo,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              autofocus: autofocus,
              maxLines: maxLines,
              maxLength: maxLength,
              textInputAction: textInputAction,
              style: const TextStyle(fontSize: 16, color: AppColors.texto),
              onChanged: (texto) {
                // ao digitar, some o erro (não fica vermelho enquanto corrige)
                if (estado.hasError) estado.validate();
                onChanged?.call(texto);
              },
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: dica,
                fillColor:
                    erro != null ? const Color(0xFFFFFBFA) : AppColors.superficie,
                enabledBorder: erro == null
                    ? null
                    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.erro, width: 1.5),
                      ),
                focusedBorder: erro == null
                    ? null
                    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.erro, width: 2),
                      ),
              ),
            ),
            if (erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AppColors.erro),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(erro,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.erro)),
                    ),
                  ],
                ),
              )
            else if (ajuda != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(ajuda!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textoSuave)),
              ),
          ],
        );
      },
    );
  }
}
