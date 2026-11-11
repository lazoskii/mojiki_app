// Toda a comunicação do app com o backend (FastAPI) passa por aqui.
// As telas nunca chamam o http direto: chamam ApiService.criarDeck(...) etc.
// Cada método:
//   1. monta a requisição (_enviar cuida de timeout e falta de internet);
//   2. confere a resposta (_decodificar transforma erro em ApiException);
//   3. converte o JSON no model do app (Deck, Flashcard...).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../models/importacao.dart';

// Endereço do backend definido no build, pra versão publicada (GitHub
// Pages) apontar pro backend online:
//   flutter build web --dart-define=API_URL=https://meu-backend.onrender.com
// Vazio (o normal no dia a dia) = usa o backend local, abaixo.
const _apiUrlDoBuild = String.fromEnvironment('API_URL');

// Sem API_URL, detecta automaticamente a plataforma:
// - Android Emulator acessa o PC via 10.0.2.2
// - Windows/Web/iOS usam 127.0.0.1 normalmente
String get _baseUrl {
  if (_apiUrlDoBuild.isNotEmpty) {
    return _apiUrlDoBuild.endsWith('/')
        ? _apiUrlDoBuild.substring(0, _apiUrlDoBuild.length - 1)
        : _apiUrlDoBuild;
  }
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
  // `limite`: 10s pras chamadas normais; a importação usa mais (OCR demora).
  static Future<http.Response> _enviar(
    Future<http.Response> Function() requisicao, {
    Duration limite = const Duration(seconds: 10),
  }) async {
    try {
      return await requisicao().timeout(limite);
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
        final corpo = jsonDecode(_texto(res));
        if (corpo is Map && corpo['detail'] is String) {
          throw ApiException(corpo['detail']);
        }
      } on FormatException {
        // corpo não é JSON: cai na mensagem genérica abaixo
      }
      throw ApiException('Erro no servidor (${res.statusCode}). Tente novamente.');
    }
    final corpo = jsonDecode(_texto(res));
    if (corpo is Map && corpo.containsKey('erro')) {
      throw ApiException(corpo['erro'].toString());
    }
    return corpo;
  }

  // O FastAPI responde em UTF-8 mas sem dizer o charset no cabeçalho; o
  // res.body poderia decodificar como latin-1 e embaralhar "água" e "水".
  // Lê os bytes como UTF-8 (e cai no res.body se não for UTF-8 válido).
  static String _texto(http.Response res) {
    try {
      return utf8.decode(res.bodyBytes);
    } on FormatException {
      return res.body;
    }
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
  // IMPORTAÇÃO (RF11 arquivo / RF12 foto)
  // ========================

  // Manda o arquivo (Anki, Excel, CSV, PDF ou foto) pro backend e recebe a
  // prévia dos cards encontrados. Nada é gravado ainda.
  static Future<PreviaImportacao> previaImportacao({
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    final res = await _enviar(
      () async {
        final req = http.MultipartRequest(
            'POST', Uri.parse('$_baseUrl/importar/previa'))
          ..files.add(http.MultipartFile.fromBytes('arquivo', bytes,
              filename: nomeArquivo));
        return http.Response.fromStream(await client.send(req));
      },
      limite: const Duration(seconds: 90),
    );
    return PreviaImportacao.fromJson(_decodificar(res));
  }

  // RF12: prévia a partir do TEXTO de uma foto já lida no aparelho
  // (ML Kit / Tesseract.js); o backend só separa japonês e português.
  static Future<PreviaImportacao> previaDeTexto(String texto) async {
    final res = await _enviar(
      () => client.post(
        Uri.parse('$_baseUrl/importar/texto'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'texto': texto}),
      ),
      limite: const Duration(seconds: 30),
    );
    return PreviaImportacao.fromJson(_decodificar(res));
  }

  // Cria um deck novo já com os cards revisados na prévia.
  static Future<Deck> importarDeck({
    required String nome,
    required List<CardImportado> cards,
  }) async {
    final res = await _enviar(
      () => client.post(
        Uri.parse('$_baseUrl/decks/importar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome,
          'user_id': usuarioFixoId,
          'cards': cards.map((c) => c.toJson()).toList(),
        }),
      ),
      limite: const Duration(seconds: 30),
    );
    return Deck.fromJson(_decodificar(res));
  }

  // Adiciona os cards revisados num deck que já existe (foto → cards
  // de dentro da tela de estudo).
  static Future<List<Flashcard>> adicionarCards({
    required int deckId,
    required List<CardImportado> cards,
  }) async {
    final res = await _enviar(
      () => client.post(
        Uri.parse('$_baseUrl/decks/$deckId/flashcards/lote'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cards': cards.map((c) => c.toJson()).toList()}),
      ),
      limite: const Duration(seconds: 30),
    );
    final List data = _decodificar(res);
    return data.map((c) => Flashcard.fromJson(c)).toList();
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
