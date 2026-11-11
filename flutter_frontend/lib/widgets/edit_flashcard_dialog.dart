import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../services/api_service.dart';

// Diálogo de edição de flashcard (Bloco 5 / RF06). Já salva via
// PUT /flashcards/{id} e devolve o card atualizado, ou null se cancelar.
Future<Flashcard?> mostrarEditarFlashcard(
  BuildContext context,
  Flashcard card,
) {
  return showDialog<Flashcard>(
    context: context,
    builder: (_) => _EditarFlashcardDialog(card: card),
  );
}

// StatefulWidget pra que o próprio diálogo crie e descarte os controllers:
// descartar logo depois do showDialog retornar quebrava a animação de
// fechar ("TextEditingController was used after being disposed").
class _EditarFlashcardDialog extends StatefulWidget {
  final Flashcard card;
  const _EditarFlashcardDialog({required this.card});

  @override
  State<_EditarFlashcardDialog> createState() => _EditarFlashcardDialogState();
}

class _EditarFlashcardDialogState extends State<_EditarFlashcardDialog> {
  late final _perguntaController =
      TextEditingController(text: widget.card.pergunta);
  late final _respostaController =
      TextEditingController(text: widget.card.resposta);
  final _formKey = GlobalKey<FormState>();
  var _salvando = false;

  @override
  void dispose() {
    _perguntaController.dispose();
    _respostaController.dispose();
    super.dispose();
  }

  String? _obrigatorio(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Campo obrigatório' : null;

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final novo = await ApiService.atualizarFlashcard(
        id: widget.card.id,
        pergunta: _perguntaController.text.trim(),
        resposta: _respostaController.text.trim(),
        deckId: widget.card.deckId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(novo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar flashcard'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _perguntaController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Pergunta',
                border: OutlineInputBorder(),
              ),
              validator: _obrigatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _respostaController,
              decoration: const InputDecoration(
                labelText: 'Resposta',
                border: OutlineInputBorder(),
              ),
              validator: _obrigatorio,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
