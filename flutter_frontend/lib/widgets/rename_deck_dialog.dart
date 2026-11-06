import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../services/api_service.dart';

// Diálogo de renomear deck (Bloco 5 / RF07). Já salva via PUT /decks/{id}
// e devolve o deck atualizado, ou null se cancelar.
Future<Deck?> mostrarRenomearDeck(BuildContext context, Deck deck) async {
  final controller = TextEditingController(text: deck.nome);
  final formKey = GlobalKey<FormState>();
  var salvando = false;

  final atualizado = await showDialog<Deck>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Renomear deck'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome do deck',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Campo obrigatório' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: salvando ? null : () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: salvando
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    setState(() => salvando = true);
                    try {
                      final novo = await ApiService.renomearDeck(
                        deck.id,
                        controller.text.trim(),
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop(novo);
                    } catch (e) {
                      setState(() => salvando = false);
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
            child: salvando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    ),
  );

  controller.dispose();
  return atualizado;
}
