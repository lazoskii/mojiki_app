// Recuperar senha em 2 passos:
//   1. digita o e-mail → o backend manda um código de 6 dígitos;
//   2. digita o código + a senha nova → já entra na conta.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validacao_login.dart';
import '../widgets/app_campo.dart';
import '../widgets/requisitos_senha.dart';
import 'login_screen.dart';

class RecuperarSenhaScreen extends StatefulWidget {
  const RecuperarSenhaScreen({super.key});

  @override
  State<RecuperarSenhaScreen> createState() => _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends State<RecuperarSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _codigo = TextEditingController();
  final _senha = TextEditingController();
  final _confirmar = TextEditingController();

  bool _codigoEnviado = false; // false = passo 1, true = passo 2
  bool _carregando = false;
  bool _verSenha = false;
  String? _erro;
  String? _aviso; // mensagem verde do backend ("você vai receber um código")

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
    _senha.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  // Roda uma chamada ao servidor com o botão travado e o erro tratado
  Future<void> _comCarregando(Future<void> Function() acao) async {
    if (_carregando) return;
    setState(() {
      _erro = null;
      _carregando = true;
    });
    try {
      await acao();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // passo 1 (também usado no "Reenviar código")
  Future<void> _pedirCodigo() async {
    if (validarEmail(_email.text) != null) {
      _formKey.currentState!.validate(); // mostra o erro no campo de e-mail
      return;
    }
    await _comCarregando(() async {
      final msg = await ApiService.pedirRecuperacao(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _codigoEnviado = true;
        _aviso = msg;
      });
    });
  }

  // passo 2
  Future<void> _redefinir() async {
    if (!_formKey.currentState!.validate()) return;
    await _comCarregando(() async {
      final resposta = await ApiService.redefinirSenha(
        email: _email.text.trim(),
        codigo: _codigo.text.trim(),
        novaSenha: _senha.text,
      );
      await AuthService.salvar(resposta); // senha trocada = já entra
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha alterada! Você já entrou na sua conta.')));
      context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        // voltar: tira esta tela da pilha (ou vai pro login se abriu direto pela URL)
        leading: BackButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/login')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CabecalhoLogin(
                      titulo: 'Recuperar senha',
                      subtitulo: _codigoEnviado
                          ? 'Digite o código enviado para ${_email.text.trim()}'
                          : 'Vamos mandar um código para o e-mail da sua conta',
                    ),
                    const SizedBox(height: 28),
                    AppCampo(
                      key: const ValueKey('email'),
                      controller: _email,
                      rotulo: 'E-mail',
                      dica: 'voce@exemplo.com',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.done,
                      onSubmitted: _codigoEnviado ? null : (_) => _pedirCodigo(),
                      // mudou o e-mail depois de pedir o código: volta pro passo 1
                      onChanged: (_) {
                        if (_codigoEnviado) setState(() => _codigoEnviado = false);
                      },
                      validator: validarEmail,
                    ),
                    if (_codigoEnviado) ...[
                      const SizedBox(height: 16),
                      AppCampo(
                        key: const ValueKey('codigo'),
                        controller: _codigo,
                        rotulo: 'Código',
                        dica: '6 dígitos',
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        textInputAction: TextInputAction.next,
                        validator: (t) => RegExp(r'^\d{6}$').hasMatch(t.trim())
                            ? null
                            : 'O código tem 6 números',
                      ),
                      const SizedBox(height: 8),
                      AppCampo(
                        key: const ValueKey('senha'),
                        controller: _senha,
                        rotulo: 'Nova senha',
                        obscureText: !_verSenha,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        suffixIcon: IconButton(
                          tooltip: _verSenha ? 'Esconder senha' : 'Mostrar senha',
                          icon: Icon(_verSenha ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _verSenha = !_verSenha),
                        ),
                        validator: validarSenha,
                      ),
                      RequisitosSenha(controller: _senha),
                      const SizedBox(height: 16),
                      AppCampo(
                        key: const ValueKey('confirmar'),
                        controller: _confirmar,
                        rotulo: 'Confirmar nova senha',
                        obscureText: !_verSenha,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _redefinir(),
                        validator: (t) =>
                            t != _senha.text ? 'As senhas não são iguais' : null,
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_erro != null) ...[
                      AvisoErro(_erro!),
                      const SizedBox(height: 16),
                    ] else if (_aviso != null && _codigoEnviado) ...[
                      _AvisoOk(_aviso!),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                      onPressed: _carregando
                          ? null
                          : (_codigoEnviado ? _redefinir : _pedirCodigo),
                      child: _carregando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : Text(_codigoEnviado ? 'Redefinir senha' : 'Enviar código'),
                    ),
                    if (_codigoEnviado)
                      TextButton(
                        onPressed: _carregando ? null : _pedirCodigo,
                        child: const Text('Não recebi: reenviar código'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Caixa verde com a confirmação de envio do código
class _AvisoOk extends StatelessWidget {
  final String mensagem;
  const _AvisoOk(this.mensagem);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.verdeClaro,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 18, color: AppColors.verde),
          const SizedBox(width: 8),
          Expanded(
            child: Text(mensagem, style: const TextStyle(color: AppColors.verde)),
          ),
        ],
      ),
    );
  }
}
