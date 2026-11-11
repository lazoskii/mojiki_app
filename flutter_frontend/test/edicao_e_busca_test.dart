// Testes de widget dos Blocos 5 (edição de flashcard e de deck) e 7 (busca
// de decks e de cards). Mesmo esquema do widget_test.dart: o ApiService
// recebe um MockClient que responde na hora, sem backend rodando.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mojiki/screens/home_screen.dart';
import 'package:mojiki/screens/study_screen.dart';
import 'package:mojiki/services/api_service.dart';
import 'package:mojiki/utils/busca.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Backend falso: devolve os dados abaixo e anota cada requisição feita.
class _BackendFalso {
  final requisicoes = <String>[];
  final corpos = <String, dynamic>{};

  final decks = [
    {'id': 1, 'nome': 'Matemática', 'user_id': 1, 'total_cards': 2},
    {'id': 2, 'nome': 'Japonês', 'user_id': 1, 'total_cards': 0},
  ];
  final cards = [
    {'id': 10, 'pergunta': '2 + 2', 'resposta': '4', 'deck_id': 1},
    {'id': 11, 'pergunta': 'Raiz de 9', 'resposta': '3', 'deck_id': 1},
  ];

  MockClient get client => MockClient((req) async {
        final rota = '${req.method} ${req.url.path}';
        requisicoes.add(rota);
        if (req.body.isNotEmpty) corpos[rota] = jsonDecode(req.body);

        dynamic body;
        switch (rota) {
          case 'GET /decks':
            body = decks;
          case 'GET /decks/1':
            body = {...decks[0], 'cards': cards};
          case 'POST /study-sessions':
            body = {'id': 99, 'user_id': 1, 'deck_id': 1, 'acertos': 0, 'erros': 0};
          case 'PUT /flashcards/10':
            body = {'id': 10, ...corpos[rota]};
          case 'PUT /decks/1':
            body = {'id': 1, 'nome': corpos[rota]['nome'], 'user_id': 1};
          case 'POST /decks':
            // simula a validação do backend (RF01) recusando o nome
            return http.Response(
                jsonEncode({'detail': 'O campo Nome do deck não pode ficar vazio'}),
                400,
                headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (body == null) return http.Response('', 404);
        return http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

// Tela do tamanho de um celular (a padrão do teste, 800x600, deixa
// botões da tela de estudo fora da área visível).
void _telaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _assentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
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

  group('Bloco 5 — edição', () {
    testWidgets('editar flashcard chama PUT /flashcards/{id} e atualiza a tela',
        (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(home: StudyScreen(deckId: 1)));
      await _assentar(tester);
      expect(find.text('2 + 2'), findsOneWidget);

      await tester.tap(find.text('Editar card'));
      await _assentar(tester);

      final campos = find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(campos.at(0), '3 + 3');
      await tester.enterText(campos.at(1), '6');
      await tester.tap(find.text('Salvar'));
      await _assentar(tester);

      expect(backend.requisicoes, contains('PUT /flashcards/10'));
      expect(backend.corpos['PUT /flashcards/10'],
          {'pergunta': '3 + 3', 'resposta': '6', 'deck_id': 1});
      expect(find.text('3 + 3'), findsOneWidget);
      expect(find.text('2 + 2'), findsNothing);
    });

    testWidgets('editar flashcard com campo vazio não chama a API',
        (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(home: StudyScreen(deckId: 1)));
      await _assentar(tester);

      await tester.tap(find.text('Editar card'));
      await _assentar(tester);
      final campos = find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(campos.at(0), '   ');
      await tester.tap(find.text('Salvar'));
      await _assentar(tester);

      expect(find.text('Campo obrigatório'), findsOneWidget);
      expect(backend.requisicoes, isNot(contains('PUT /flashcards/10')));
    });

    testWidgets('renomear deck chama PUT /decks/{id} e mantém a contagem',
        (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await _assentar(tester);
      // o nome aparece no card do deck e no atalho "Continuar"
      expect(find.text('Matemática'), findsWidgets);
      expect(find.text('2 cards'), findsOneWidget);

      await tester.tap(find.byTooltip('Opções do deck').first);
      await _assentar(tester);
      await tester.tap(find.text('Renomear'));
      await _assentar(tester);
      final campo = find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(campo, 'Álgebra');
      await tester.tap(find.text('Salvar'));
      await _assentar(tester);

      expect(backend.corpos['PUT /decks/1'], {'nome': 'Álgebra'});
      expect(find.text('Álgebra'), findsWidgets);
      expect(find.text('Matemática'), findsNothing);
      expect(find.text('2 cards'), findsOneWidget);
    });
  });

  group('RF01 — validação do nome do deck', () {
    testWidgets('nome só com espaços avisa e não chama a API', (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await _assentar(tester);

      await tester.tap(find.text('Novo deck'));
      await _assentar(tester);
      await tester.enterText(
          find.descendant(
              of: find.byType(BottomSheet), matching: find.byType(TextField)),
          '    ');
      await tester.tap(find.text('Criar deck'));
      await _assentar(tester);

      expect(find.text('Digite um nome para o deck.'), findsOneWidget);
      expect(backend.requisicoes, isNot(contains('POST /decks')));
    });

    testWidgets('erro 400 do backend mostra a mensagem dele', (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await _assentar(tester);

      await tester.tap(find.text('Novo deck'));
      await _assentar(tester);
      await tester.enterText(
          find.descendant(
              of: find.byType(BottomSheet), matching: find.byType(TextField)),
          'Kanji');
      await tester.tap(find.text('Criar deck'));
      await _assentar(tester);

      expect(backend.requisicoes, contains('POST /decks'));
      expect(find.text('O campo Nome do deck não pode ficar vazio'),
          findsOneWidget);
    });
  });

  group('Bloco 7 — busca', () {
    test('busca ignora maiúsculas e acentos', () {
      expect(normalizar('MATEMÁTICA'), 'matematica');
      expect(combinaBusca('matematica', ['Matemática']), isTrue);
      expect(combinaBusca('japo', ['Matemática']), isFalse);
      expect(combinaBusca('  ', ['qualquer coisa']), isTrue);
    });

    testWidgets('busca de decks filtra a Home pelo nome', (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await _assentar(tester);
      expect(find.text('Matemática'), findsWidgets);
      expect(find.text('Japonês'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Buscar deck pelo nome'), 'japones');
      await _assentar(tester);
      expect(find.text('Matemática'), findsNothing);
      expect(find.text('Japonês'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Buscar deck pelo nome'), 'xyz');
      await _assentar(tester);
      expect(find.text('Nenhum deck encontrado para "xyz"'), findsOneWidget);
    });

    testWidgets('busca de cards acha pela resposta e pula pro card',
        (tester) async {
      _telaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(home: StudyScreen(deckId: 1)));
      await _assentar(tester);
      expect(find.text('2 + 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Buscar card'));
      await _assentar(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Pergunta ou resposta'), '3');
      await _assentar(tester);

      // só o card "Raiz de 9" (resposta 3) combina
      final lista = find.byType(ListTile);
      expect(lista, findsOneWidget);
      await tester.tap(lista);
      await _assentar(tester);

      expect(find.text('Raiz de 9'), findsOneWidget);
      expect(find.text('Card 2 de 2'), findsOneWidget);
    });
  });
}
