// Testes que comprovam, do lado do app, os requisitos básicos do README
// (RF02–RF05 e RF08). Cada `group` é um requisito; cada teste é um caso de
// teste de docs/casos_de_teste.md virado em código. RF01, RF06, RF07 e a
// busca já estão em edicao_e_busca_test.dart; o Acertei/Errei (Bloco 1) em
// widget_test.dart; as regras do servidor em backend/test_requisitos.py.
//
// Mesmo esquema dos outros testes: o ApiService recebe um MockClient (um
// backend falso que responde na hora), então não precisa de servidor rodando.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mojiki/models/modo_estudo.dart';
import 'package:mojiki/screens/home_screen.dart';
import 'package:mojiki/screens/study_screen.dart';
import 'package:mojiki/screens/study_session_screen.dart';
import 'package:mojiki/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Backend falso: devolve os dados abaixo e anota cada requisição feita.
//   offline = true   -> toda chamada falha como se a rede tivesse caído
//   travado = true   -> o servidor nunca responde (testa o timeout)
class _BackendFalso {
  final requisicoes = <String>[];
  final corpos = <String, dynamic>{};
  bool offline = false;
  bool travado = false;

  final decks = <Map<String, dynamic>>[
    {'id': 1, 'nome': 'Matemática', 'user_id': 1, 'total_cards': 2},
    {'id': 2, 'nome': 'Vazio', 'user_id': 1, 'total_cards': 0},
  ];
  List<Map<String, dynamic>> cards = [
    {'id': 10, 'pergunta': '2 + 2', 'resposta': '4', 'deck_id': 1},
    {'id': 11, 'pergunta': 'Raiz de 9', 'resposta': '3', 'deck_id': 1},
  ];

  MockClient get client => MockClient((req) async {
        final rota = '${req.method} ${req.url.path}';
        requisicoes.add(rota);
        if (req.body.isNotEmpty) corpos[rota] = jsonDecode(req.body);
        if (travado) return Completer<http.Response>().future;
        if (offline) throw http.ClientException('rede caiu');

        dynamic body;
        switch (rota) {
          case 'GET /decks':
            body = decks;
          case 'GET /decks/1':
            body = {...decks[0], 'cards': cards};
          case 'GET /decks/2':
            body = {...decks[1], 'cards': []};
          case 'POST /study-sessions':
            body = {'id': 99, 'user_id': 1, 'deck_id': 1, 'acertos': 0, 'erros': 0};
          case 'POST /study-sessions/99/responder':
          case 'PUT /study-sessions/99/finalizar':
            body = {'msg': 'ok'};
          case 'DELETE /decks/1':
            body = {'msg': 'Deck deletado'};
          case 'DELETE /flashcards/10':
            body = {'msg': 'Flashcard deletado'};
        }
        if (body == null) return http.Response('', 404);
        return http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

// Tela do tamanho de um celular (a padrão, 800x600, esconde botões).
void _telaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _assentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

// Vira o card que estiver na tela (no modo, a ordem é embaralhada, então
// procura qual das perguntas está visível).
Future<void> _virarCard(WidgetTester tester, List<String> perguntas) async {
  final atual = perguntas.firstWhere((p) => find.text(p).evaluate().isNotEmpty);
  await tester.tap(find.text(atual));
  await _assentar(tester);
}

void main() {
  late http.Client clienteOriginal;
  late _BackendFalso backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({'userName': 'Teste'});
    clienteOriginal = ApiService.client;
    backend = _BackendFalso();
    ApiService.client = backend.client;
  });

  tearDown(() => ApiService.client = clienteOriginal);

  group('RF02 — pergunta e resposta obrigatórias', () {
    testWidgets('card sem resposta avisa e não chama a API', (tester) async {
      _telaDeCelular(tester);
      // deck vazio: o formulário de novo card já aparece aberto
      await tester.pumpWidget(const MaterialApp(home: StudyScreen(deckId: 2)));
      await _assentar(tester);

      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), '水');
      await tester.enterText(campos.at(1), '   ');
      await tester.tap(find.text('Criar flashcard'));
      await _assentar(tester);

      expect(find.text('Preencha a pergunta e a resposta.'), findsOneWidget);
      expect(backend.requisicoes, isNot(contains('POST /flashcards')));
    });
  });

  group('RF03 — erro de API não trava no carregando', () {
    testWidgets('Home sem rede mostra erro e "Tentar novamente" recupera',
        (tester) async {
      _telaDeCelular(tester);
      backend.offline = true;
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await _assentar(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Sem conexão'), findsOneWidget);
      expect(find.textContaining('Não foi possível conectar'), findsOneWidget);

      backend.offline = false; // a rede voltou
      await tester.tap(find.text('Tentar novamente'));
      await _assentar(tester);

      expect(find.text('Sem conexão'), findsNothing);
      expect(find.text('Matemática'), findsWidgets);
    });

    testWidgets('servidor que não responde: sai do spinner após o timeout',
        (tester) async {
      _telaDeCelular(tester);
      backend.travado = true;
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 11)); // limite é 10 s
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('tela de estudo de um deck sem rede mostra o erro',
        (tester) async {
      _telaDeCelular(tester);
      backend.offline = true;
      await tester.pumpWidget(const MaterialApp(home: StudyScreen(deckId: 1)));
      await _assentar(tester);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('tela Estudar (modos) sem rede mostra o erro', (tester) async {
      _telaDeCelular(tester);
      backend.offline = true;
      await tester.pumpWidget(const MaterialApp(home: StudySessionScreen()));
      await _assentar(tester);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });

  group('RF04 — confirmação antes de excluir deck', () {
    Future<void> abrirExclusao(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Opções do deck').first);
      await _assentar(tester);
      await tester.tap(find.text('Excluir'));
      await _assentar(tester);
    }

    testWidgets('Cancelar não apaga; Excluir apaga', (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await _assentar(tester);

      await abrirExclusao(tester);
      expect(find.text('Excluir deck?'), findsOneWidget);
      // avisa que os flashcards também vão embora
      expect(find.textContaining('todos os seus flashcards'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await _assentar(tester);
      expect(backend.requisicoes, isNot(contains('DELETE /decks/1')));
      expect(find.text('2 cards'), findsOneWidget); // o deck continua lá

      await abrirExclusao(tester);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Excluir')));
      await _assentar(tester);
      expect(backend.requisicoes, contains('DELETE /decks/1'));
      expect(find.text('2 cards'), findsNothing);
    });
  });

  group('RF05 — confirmação antes de excluir flashcard', () {
    testWidgets('Cancelar não apaga; Excluir apaga', (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(home: StudyScreen(deckId: 1)));
      await _assentar(tester);

      await tester.tap(find.text('Deletar card'));
      await _assentar(tester);
      expect(find.text('Excluir flashcard?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await _assentar(tester);
      expect(backend.requisicoes, isNot(contains('DELETE /flashcards/10')));
      expect(find.text('2 + 2'), findsOneWidget);

      await tester.tap(find.text('Deletar card'));
      await _assentar(tester);
      await tester.tap(find.text('Excluir'));
      await _assentar(tester);
      expect(backend.requisicoes, contains('DELETE /flashcards/10'));
      expect(find.text('2 + 2'), findsNothing);
      expect(find.text('Card 1 de 1'), findsOneWidget);
    });
  });

  group('RF08 — modos de estudo', () {
    testWidgets('tocar no modo lista só decks com cards e abre o estudo',
        (tester) async {
      _telaDeCelular(tester);
      final router = GoRouter(initialLocation: '/study-session', routes: [
        GoRoute(
            path: '/study-session',
            builder: (_, _) => const StudySessionScreen()),
        GoRoute(
            path: '/study/:deckId',
            builder: (_, state) => Text('abriu ${state.uri}')),
      ]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _assentar(tester);

      await tester.tap(find.text('Sessão Rápida'));
      await _assentar(tester);
      expect(find.text('Escolha o deck'), findsOneWidget);
      final lista = find.byType(ListTile);
      expect(find.descendant(of: lista, matching: find.text('Matemática')),
          findsOneWidget);
      // deck sem cards não aparece pra escolher
      expect(find.descendant(of: lista, matching: find.text('Vazio')),
          findsNothing);

      await tester.tap(find.descendant(of: lista, matching: find.text('Matemática')));
      await _assentar(tester);
      expect(find.text('abriu /study/1?modo=rapida&voltar=/study-session'),
          findsOneWidget);
    });

    testWidgets('Sessão Rápida: até 10 cards, 5 min e finaliza no tempo',
        (tester) async {
      _telaDeCelular(tester);
      backend.cards = [
        for (var i = 0; i < 12; i++)
          {'id': 100 + i, 'pergunta': 'P$i', 'resposta': 'R$i', 'deck_id': 1},
      ];
      await tester.pumpWidget(const MaterialApp(
          home: StudyScreen(deckId: 1, modo: ModoEstudo.rapida)));
      await _assentar(tester);

      expect(find.text('Card 1 de 10'), findsOneWidget); // 12 cortados em 10
      expect(find.text('05:00'), findsOneWidget);
      expect(backend.corpos['POST /study-sessions'],
          {'deck_id': 1, 'modo': 'rapida'});

      await tester.pump(const Duration(minutes: 5));
      await _assentar(tester);

      expect(find.text('Tempo esgotado!'), findsOneWidget);
      expect(find.text('Estudar novamente'), findsOneWidget); // resultado
      expect(backend.requisicoes, contains('PUT /study-sessions/99/finalizar'));
      await tester.pump(const Duration(seconds: 5)); // some o SnackBar
    });

    testWidgets('Sessão Intensiva: card errado volta pro fim da fila',
        (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(
          home: StudyScreen(deckId: 1, modo: ModoEstudo.intensiva)));
      await _assentar(tester);
      expect(find.text('Card 1 de 2'), findsOneWidget);
      expect(find.text('30:00'), findsOneWidget);

      await _virarCard(tester, ['2 + 2', 'Raiz de 9']);
      await tester.tap(find.text('Errei'));
      await _assentar(tester);

      expect(find.text('Card 2 de 3'), findsOneWidget); // ganhou uma repetição
      expect(backend.corpos['POST /study-sessions'],
          {'deck_id': 1, 'modo': 'intensiva'});
      expect(backend.requisicoes, contains('POST /study-sessions/99/responder'));
    });

    testWidgets('Prática Diária: todos os cards e 15 min', (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(
          home: StudyScreen(deckId: 1, modo: ModoEstudo.diaria)));
      await _assentar(tester);
      expect(find.text('Card 1 de 2'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);

      // errar na Diária NÃO repete o card
      await _virarCard(tester, ['2 + 2', 'Raiz de 9']);
      await tester.tap(find.text('Errei'));
      await _assentar(tester);
      expect(find.text('Card 2 de 2'), findsOneWidget);
    });
  });
}
