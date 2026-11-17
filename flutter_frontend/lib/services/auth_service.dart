// Guarda quem está logado: o token devolvido pelo backend fica salvo no
// aparelho (SharedPreferences) e vai em toda requisição (ver api_service.dart).
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _kToken = 'authToken';
  static const _kEmail = 'userEmail';
  // 'userName' é a mesma chave que as telas já liam para mostrar "Olá, ..."
  static const _kUsuario = 'userName';

  // em memória: o go_router precisa saber na hora (sem await) se está logado
  static String? token;
  static String? usuario;

  static bool get logado => token != null;

  // Chamado quando o backend responde 401 (token vencido ou apagado);
  // o main.dart liga isto em "limpar e abrir a tela de login".
  static void Function()? aoExpirarSessao;

  // Lê o token salvo, uma vez, antes de o app abrir (main.dart)
  static Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_kToken);
    usuario = prefs.getString(_kUsuario);
  }

  // Depois de entrar/cadastrar/redefinir a senha: guarda a resposta do backend
  static Future<void> salvar(Map<String, dynamic> resposta) async {
    token = resposta['token'] as String;
    usuario = resposta['usuario'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token!);
    await prefs.setString(_kUsuario, usuario!);
    await prefs.setString(_kEmail, resposta['email'] as String? ?? '');
    await prefs.remove('isAuthenticated'); // chave da versão antiga (só nome)
  }

  // Sair: esquece o token neste aparelho
  static Future<void> limpar() async {
    token = null;
    usuario = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUsuario);
    await prefs.remove(_kEmail);
    // "Continuar estudando" apontaria pra um deck da conta anterior
    await prefs.remove('ultimoDeckId');
  }
}
