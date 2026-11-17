// Regras dos campos de login — as mesmas do backend (backend/auth.py).
// Cada função devolve a mensagem de erro, ou null se o texto está certo
// (é o formato que o `validator` do AppCampo espera).

// Requisitos da senha, um por linha, para a lista que aparece no cadastro
final requisitosSenha = <({String texto, bool Function(String) ok})>[
  (texto: 'Pelo menos 8 caracteres', ok: (s) => s.length >= 8),
  (texto: 'Um número', ok: (s) => RegExp(r'[0-9]').hasMatch(s)),
  // maiúscula = muda quando passa pra minúscula (aceita "Á", como o isupper do Python)
  (texto: 'Uma letra maiúscula', ok: (s) => s.split('').any((c) => c != c.toLowerCase())),
];

String? validarSenha(String senha) {
  if (senha.isEmpty) return 'Digite a senha';
  if (senha.length < 8) return 'A senha precisa ter pelo menos 8 caracteres';
  if (senha.length > 128) return 'A senha pode ter no máximo 128 caracteres';
  if (!requisitosSenha[1].ok(senha)) return 'A senha precisa ter pelo menos um número';
  if (!requisitosSenha[2].ok(senha)) return 'A senha precisa ter pelo menos uma letra maiúscula';
  return null;
}

String? validarUsuario(String usuario) {
  final u = usuario.trim();
  if (u.isEmpty) return 'Digite o nome de usuário';
  if (!RegExp(r'^[A-Za-z0-9._]{3,30}$').hasMatch(u)) {
    return 'Use de 3 a 30 caracteres: letras, números, ponto ou _';
  }
  return null;
}

String? validarEmail(String email) {
  final e = email.trim();
  if (e.isEmpty) return 'Digite o e-mail';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'Digite um e-mail válido';
  return null;
}
