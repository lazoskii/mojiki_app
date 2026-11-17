// Tela de login: "Entrar" (usuário + senha) e "Criar conta" (usuário,
// e-mail e senha) na mesma tela, trocando por um seletor no topo.
// Substitui a antiga tela de boas-vindas, que só pedia o nome.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validacao_login.dart';
import '../widgets/app_campo.dart';
import '../widgets/requisitos_senha.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmar = TextEditingController();

  bool _criandoConta = false; // false = Entrar, true = Criar conta
  bool _verSenha = false;
  bool _carregando = false; // trava o botão enquanto espera o servidor
  String? _erro; // mensagem do backend (ex.: "Usuário ou senha incorretos")

  @override
  void dispose() {
    _usuario.dispose();
    _email.dispose();
    _senha.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  void _trocarModo(bool criandoConta) {
    setState(() {
      _criandoConta = criandoConta;
      _erro = null;
    });
    _formKey.currentState?.reset(); // tira os erros vermelhos do modo anterior
  }

  Future<void> _enviar() async {
    if (_carregando) return; // evita mandar duas vezes (Enter + clique)
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);
    try {
      final resposta = _criandoConta
          ? await ApiService.cadastrar(
              usuario: _usuario.text.trim(),
              email: _email.text.trim(),
              senha: _senha.text,
            )
          : await ApiService.entrar(
              usuario: _usuario.text.trim(),
              senha: _senha.text,
            );
      await AuthService.salvar(resposta); // guarda o token no aparelho
      if (!mounted) return;
      context.go('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // botão de olho no fim do campo de senha (mostrar/esconder)
  Widget get _botaoVerSenha => IconButton(
        tooltip: _verSenha ? 'Esconder senha' : 'Mostrar senha',
        icon: Icon(_verSenha ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => _verSenha = !_verSenha),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420), // não esticar no PC
              // AutofillGroup: o navegador/celular oferece salvar a senha
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CabecalhoLogin(
                        titulo: _criandoConta ? 'Criar conta' : 'Entrar',
                        subtitulo: _criandoConta
                            ? 'Leva menos de um minuto'
                            : 'Que bom te ver de novo!',
                      ),
                      const SizedBox(height: 24),
                      // seletor Entrar | Criar conta
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Entrar')),
                          ButtonSegment(value: true, label: Text('Criar conta')),
                        ],
                        selected: {_criandoConta},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => _trocarModo(s.first),
                      ),
                      const SizedBox(height: 24),
                      AppCampo(
                        key: const ValueKey('usuario'),
                        controller: _usuario,
                        rotulo: 'Usuário',
                        dica: 'Ex.: alexandre',
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        // no login só confere se está vazio (a regra é do cadastro)
                        validator: _criandoConta
                            ? validarUsuario
                            : (t) => t.trim().isEmpty ? 'Digite seu usuário' : null,
                      ),
                      if (_criandoConta) ...[
                        const SizedBox(height: 16),
                        AppCampo(
                          key: const ValueKey('email'),
                          controller: _email,
                          rotulo: 'E-mail',
                          dica: 'voce@exemplo.com',
                          ajuda: 'Usado só para recuperar a senha',
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          validator: validarEmail,
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppCampo(
                        key: const ValueKey('senha'),
                        controller: _senha,
                        rotulo: 'Senha',
                        obscureText: !_verSenha,
                        suffixIcon: _botaoVerSenha,
                        autofillHints: [
                          _criandoConta ? AutofillHints.newPassword : AutofillHints.password
                        ],
                        textInputAction:
                            _criandoConta ? TextInputAction.next : TextInputAction.done,
                        onSubmitted: _criandoConta ? null : (_) => _enviar(),
                        validator: _criandoConta
                            ? validarSenha
                            : (t) => t.isEmpty ? 'Digite sua senha' : null,
                      ),
                      if (_criandoConta) ...[
                        RequisitosSenha(controller: _senha),
                        const SizedBox(height: 16),
                        AppCampo(
                          key: const ValueKey('confirmar'),
                          controller: _confirmar,
                          rotulo: 'Confirmar senha',
                          obscureText: !_verSenha,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _enviar(),
                          validator: (t) =>
                              t != _senha.text ? 'As senhas não são iguais' : null,
                        ),
                      ] else
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/recuperar-senha'),
                            child: const Text('Esqueci minha senha'),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (_erro != null) ...[
                        AvisoErro(_erro!),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        onPressed: _carregando ? null : _enviar,
                        child: _carregando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : Text(_criandoConta ? 'Criar conta' : 'Entrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Marca + título, usado aqui e na tela de recuperar senha
class CabecalhoLogin extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  const CabecalhoLogin({super.key, required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.vermelho, shape: BoxShape.circle),
          child: const Text('文',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 20),
        Text(titulo,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(subtitulo,
            style: const TextStyle(fontSize: 15, color: AppColors.textoSuave),
            textAlign: TextAlign.center),
      ],
    );
  }
}

// Caixa vermelha com a mensagem de erro do servidor
class AvisoErro extends StatelessWidget {
  final String mensagem;
  const AvisoErro(this.mensagem, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.erro.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.erro),
          const SizedBox(width: 8),
          Expanded(
            child: Text(mensagem,
                style: const TextStyle(color: AppColors.erro, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
