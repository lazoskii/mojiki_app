import 'package:flutter/material.dart';
import '../services/api_service.dart';

// Diálogo do link "Enviar feedback" no rodapé do menu lateral.
Future<void> mostrarFeedbackDialog(BuildContext context) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var enviando = false;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Enviar feedback'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'O que podemos melhorar no Mojiki?',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Escreva algo antes de enviar' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: enviando ? null : () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: enviando
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    setState(() => enviando = true);
                    try {
                      await ApiService.enviarFeedback(controller.text.trim());
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Obrigado pelo feedback!')),
                      );
                    } catch (e) {
                      setState(() => enviando = false);
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
            child: enviando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar'),
          ),
        ],
      ),
    ),
  );
}
