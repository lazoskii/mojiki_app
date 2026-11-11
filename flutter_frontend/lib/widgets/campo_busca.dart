import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Campo de busca (Bloco 7) usado na Home (decks) e na busca de cards.
// Mostra um "x" pra limpar quando tem texto. Segue o padrão das caixas de
// texto (52 px, borda bege, vermelha no foco), só que sem rótulo em cima:
// a lupa já diz o que o campo faz.
class CampoBusca extends StatelessWidget {
  final TextEditingController controller;
  final String dica;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  const CampoBusca({
    super.key,
    required this.controller,
    required this.dica,
    required this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 16, color: AppColors.texto),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: dica,
        prefixIcon: const Icon(Icons.search, size: 22),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}
