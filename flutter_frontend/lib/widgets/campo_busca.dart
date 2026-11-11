import 'package:flutter/material.dart';

// Campo de busca (Bloco 7) usado na Home (decks) e na busca de cards.
// Mostra um "x" pra limpar quando tem texto.
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
      style: const TextStyle(color: Colors.white),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: dica,
        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
