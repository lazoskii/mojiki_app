import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/deck.dart';
import '../models/flashcard.dart';

// Detecta automaticamente a plataforma:
// - Android Emulator acessa o PC via 10.0.2.2
// - Windows/Web/iOS usam 127.0.0.1 normalmente
String get _baseUrl {
  if (kIsWeb) return 'http://127.0.0.1:8000';
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
  return 'http://127.0.0.1:8000';
}

// Erro de API com mensagem já pronta pra mostrar ao usuário (RF03 —
// tratamento de erro nas chamadas de API, em vez de travar no carregando).
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

// PENDÊNCIA (backlog, Bloco 7): o app ainda não tem login, então todo deck e
// toda sessão de estudo são gravados com o mesmo usuário. Quando existir
// autenticação real, trocar esta constante pelo id do usuário logado.
// Ver a seção "Backlog" do README.
const usuarioFixoId = 1;

const _erroConexao =
    'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.';

class ApiService {
  // Cliente HTTP injetável: em produção usa um http.Client() padrão de
  // verdade; nos testes de widget dá pra trocar por um MockClient
  // (package:http/testing.dart) pra simular respostas da API sem precisar
  // de requisições de rede reais (que não funcionam dentro do ambiente de
  // tempo "fake" do testWidgets).
  static http.Client client = http.Client();

  // Executa a chamada HTTP tratando falhas de rede/timeout; quem chama
  // ainda decide o que fazer com a Response (checar status, decodificar).
  static Future<http.Response> _enviar(
    Future<http.Response> Function() requisicao,
  ) async {
    try {
      return await requisicao().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ApiException(_erroConexao);
    } on SocketException {
      throw const ApiException(_erroConexao);
    } on http.ClientException {
      throw const ApiException(_erroConexao);
    }
  }

  // Decodifica o corpo da resposta, verificando tanto o status HTTP quanto
  // o formato {"erro": "..."} que o backend usa para erros de negócio.
  static dynamic _decodificar(http.Response res) {
    if (res.statusCode >= 400) {
      // Erros de validação do FastAPI (HTTPException) vêm como
      // {"detail": "..."} — mostra essa mensagem quando ela existe.
      try {
        final corpo = jsonDecode(res.body);
        if (corpo is Map && corpo['detail'] is String) {
          throw ApiException(corpo['detail']);
        }
      } on FormatException {
        // corpo não é JSON: cai na mensagem genérica abaixo
      }
      throw ApiException('Erro no servidor (${res.statusCode}). Tente novamente.');
    }
    final corpo = jsonDecode(res.body);
    if (corpo is Map && corpo.containsKey('erro')) {
      throw ApiException(corpo['erro'].toString());
    }
    return corpo;
  }

  // ========================
  // DECKS
  // ========================

  static Future<List<Deck>> listarDecks() async {
    final res = await _enviar(() => client.get(Uri.parse('$_baseUrl/decks')));
    final List data = _decodificar(res);
    return data.map((d) => Deck.fromJson(d)).toList();
  }

  static Future<Deck> buscarDeck(int id) async {
    final res = await _enviar(() => client.get(Uri.parse('$_baseUrl/decks/$id')));
    return Deck.fromJson(_decodificar(res));
  }

  static Future<Deck> criarDeck(String nome) async {
    final res = await _enviar(() => client.post(
          Uri.parse('$_baseUrl/decks'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'nome': nome, 'user_id': usuarioFixoId}),
        ));
    return Deck.fromJson(_decodificar(res));
  }

  // RF07 — renomear deck via PUT /decks/{id}
  static Future<Deck> renomearDeck(int id, String nome) async {
    final res = await _enviar(() => client.put(
          Uri.parse('$_baseUrl/decks/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'nome': nome}),
        ));
    return Deck.fromJson(_decodificar(res));
  }

  static Future<void> deletarDeck(int id) async {
    final res = await _enviar(() => client.delete(Uri.parse('$_baseUrl/decks/$id')));
    _decodificar(res);
  }

  // ========================
  // FLASHCARDS
  // ========================

  static Future<Flashcard> criarFlashcard({
    required String pergunta,
    required String resposta,
    required int deckId,
  }) async {
    final res = await _enviar(() => client.post(
          Uri.parse('$_baseUrl/flashcards'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'pergunta': pergunta,
            'resposta': resposta,
            'deck_id': deckId,
          }),
        ));
    return Flashcard.fromJson(_decodificar(res));
  }

  // RF06 — edição de flashcard via PUT /flashcards/{id}
  static Future<Flashcard> atualizarFlashcard({
    required int id,
    required String pergunta,
    required String resposta,
    required int deckId,
  }) async {
    final res = await _enviar(() => client.put(
          Uri.parse('$_baseUrl/flashcards/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'pergunta': pergunta,
            'resposta': resposta,
            'deck_id': deckId,
          }),
        ));
    return Flashcard.fromJson(_decodificar(res));
  }

  static Future<void> deletarFlashcard(int id) async {
    final res = await _enviar(() => client.delete(Uri.parse('$_baseUrl/flashcards/$id')));
    _decodificar(res);
  }

  // ========================
  // STUDY SESSIONS (autoavaliação)
  // ========================

  static Future<Map<String, dynamic>> iniciarSessao({
    required int userId,
    required int deckId,
    String? modo, // rapida/diaria/intensiva, ou null quando aberto da Home
  }) async {
    final res = await _enviar(() => client.post(
          Uri.parse('$_baseUrl/study-sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId, 'deck_id': deckId, 'modo': modo}),
        ));
    return _decodificar(res);
  }

  static Future<Map<String, dynamic>> registrarResposta({
    required int sessaoId,
    required bool acerto,
  }) async {
    final res = await _enviar(() => client.post(
          Uri.parse('$_baseUrl/study-sessions/$sessaoId/responder'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'acerto': acerto}),
        ));
    return _decodificar(res);
  }

  static Future<void> finalizarSessao(int sessaoId) async {
    final res = await _enviar(
        () => client.put(Uri.parse('$_baseUrl/study-sessions/$sessaoId/finalizar')));
    _decodificar(res);
  }

  // ========================
  // FEEDBACK
  // ========================

  static Future<void> enviarFeedback(String mensagem) async {
    final res = await _enviar(() => client.post(
          Uri.parse('$_baseUrl/feedback'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'mensagem': mensagem}),
        ));
    _decodificar(res);
  }
}
