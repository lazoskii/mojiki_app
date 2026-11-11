// Boas-vindas: pede o nome do usuário (não existe login ainda — ver Backlog
// no README) e guarda no aparelho com SharedPreferences.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/app_campo.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // TextEditingController = equivale ao useState("") + onChange de um input
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // dispose = limpeza de recursos ao sair da tela (boa prática)
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    final nome = _nameController.text.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', nome);
    await prefs.setBool('isAuthenticated', true);

    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // SafeArea = evita que o conteúdo fique atrás da barra de status
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: AppColors.vermelho, shape: BoxShape.circle),
                      child: const Text('文',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Bem-vindo!',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Como podemos te chamar?',
                    style: TextStyle(fontSize: 16, color: AppColors.textoSuave),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // caixa de texto padrão: rótulo em cima, erro com ícone
                  AppCampo(
                    controller: _nameController,
                    rotulo: 'Seu nome',
                    dica: 'Ex.: Alexandre',
                    ajuda: 'Aparece na tela inicial',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _entrar(),
                    validator: (texto) =>
                        texto.trim().isEmpty ? 'Digite seu nome para entrar' : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _entrar,
                    child: const Text('Entrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
