import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'app_campo.dart';

// Diálogo "Enviar feedback" (menu de perfil, botão com a inicial do nome).
// Valida que não está vazio e manda pro POST /feedback.
Future<void> mostrarFeedbackDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _FeedbackDialog(),
  );
}

// StatefulWidget: o próprio diálogo cria e descarta o controller do campo
// (antes ele nunca era descartado).
class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _enviando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    // guarda o messenger antes de fechar o diálogo (depois o context some)
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.enviarFeedback(_controller.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Obrigado pelo feedback!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enviar feedback'),
      content: Form(
        key: _formKey,
        child: AppCampo(
          controller: _controller,
          rotulo: 'Sua mensagem',
          dica: 'O que podemos melhorar no Mojiki?',
          autofocus: true,
          maxLines: 4,
          maxLength: 500,
          validator: (texto) =>
              texto.trim().isEmpty ? 'Escreva algo antes de enviar' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          child: _enviando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar'),
        ),
      ],
    );
  }
}
