import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'feedback_dialog.dart';

// Botão redondo com a inicial do usuário, no canto das telas principais.
// Substitui o menu lateral (☰): a navegação foi pra barra de baixo e o
// que sobrou do menu (Enviar feedback, Sair) fica neste painel.
class BotaoPerfil extends StatelessWidget {
  final String nome;
  const BotaoPerfil({super.key, required this.nome});

  @override
  Widget build(BuildContext context) {
    final inicial = nome.trim().isEmpty ? '?' : nome.trim()[0].toUpperCase();
    return Material(
      color: AppColors.superficie,
      shape: const CircleBorder(side: BorderSide(color: AppColors.linha)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => mostrarMenuPerfil(context, nome),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(inicial,
                semanticsLabel: 'Perfil',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto)),
          ),
        ),
      ),
    );
  }
}

Future<void> mostrarMenuPerfil(BuildContext context, String nome) {
  return showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.vermelhoClaro,
                  child: Text(
                    nome.trim().isEmpty ? '?' : nome.trim()[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.vermelhoEscuro),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const Text('Estudante',
                        style: TextStyle(color: AppColors.textoSuave)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Enviar feedback'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                mostrarFeedbackDialog(context);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('isAuthenticated');
                await prefs.remove('userName');
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                if (context.mounted) context.go('/welcome');
              },
            ),
          ],
        ),
      ),
    ),
  );
}
