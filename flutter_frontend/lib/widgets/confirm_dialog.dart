import 'package:flutter/material.dart';

// Diálogo de confirmação usado antes de excluir um deck ou flashcard
// (Bloco 4 do README — exclusão não pode mais ser instantânea).
Future<bool> confirmarExclusao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}
