import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../services/api_service.dart';
import 'app_campo.dart';

// Diálogo de renomear deck (Bloco 5 / RF07). Já salva via PUT /decks/{id}
// e devolve o deck atualizado, ou null se cancelar.
Future<Deck?> mostrarRenomearDeck(BuildContext context, Deck deck) {
  return showDialog<Deck>(
    context: context,
    builder: (_) => _RenomearDeckDialog(deck: deck),
  );
}

// StatefulWidget pra que o próprio diálogo crie e descarte o controller do
// campo: descartar logo depois do showDialog retornar quebrava a animação
// de fechar ("TextEditingController was used after being disposed").
class _RenomearDeckDialog extends StatefulWidget {
  final Deck deck;
  const _RenomearDeckDialog({required this.deck});

  @override
  State<_RenomearDeckDialog> createState() => _RenomearDeckDialogState();
}

class _RenomearDeckDialogState extends State<_RenomearDeckDialog> {
  late final _controller = TextEditingController(text: widget.deck.nome);
  final _formKey = GlobalKey<FormState>();
  var _salvando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final novo = await ApiService.renomearDeck(
        widget.deck.id,
        _controller.text.trim(),
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
      title: const Text('Renomear deck'),
      content: Form(
        key: _formKey,
        child: AppCampo(
          controller: _controller,
          rotulo: 'Nome do deck',
          autofocus: true,
          validator: (texto) =>
              texto.trim().isEmpty ? 'Campo obrigatório' : null,
          onSubmitted: (_) => _salvar(),
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
