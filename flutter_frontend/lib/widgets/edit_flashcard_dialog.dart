import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../services/api_service.dart';

// Diálogo de edição de flashcard (Bloco 5 / RF06). Já salva via
// PUT /flashcards/{id} e devolve o card atualizado, ou null se cancelar.
Future<Flashcard?> mostrarEditarFlashcard(
  BuildContext context,
  Flashcard card,
) async {
  final perguntaController = TextEditingController(text: card.pergunta);
  final respostaController = TextEditingController(text: card.resposta);
  final formKey = GlobalKey<FormState>();
  var salvando = false;

  String? obrigatorio(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Campo obrigatório' : null;

  final atualizado = await showDialog<Flashcard>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Editar flashcard'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: perguntaController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Pergunta',
                  border: OutlineInputBorder(),
                ),
                validator: obrigatorio,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: respostaController,
                decoration: const InputDecoration(
                  labelText: 'Resposta',
                  border: OutlineInputBorder(),
                ),
                validator: obrigatorio,
              ),
            ],
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
                      final novo = await ApiService.atualizarFlashcard(
                        id: card.id,
                        pergunta: perguntaController.text.trim(),
                        resposta: respostaController.text.trim(),
                        deckId: card.deckId,
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

  perguntaController.dispose();
  respostaController.dispose();
  return atualizado;
}
