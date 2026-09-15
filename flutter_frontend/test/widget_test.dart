// Smoke test básico: garante que o app sobe sem lançar exceções e que a
// tela inicial (Splash) é exibida.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mojiki/main.dart';
import 'package:mojiki/screens/study_screen.dart';
import 'package:mojiki/services/api_service.dart';

void main() {
  testWidgets('App inicia na tela de Splash', (WidgetTester tester) async {
    await tester.pumpWidget(const MojikiApp());
    await tester.pump();

    expect(find.text('日本語'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Deixa o timer de 2s do Splash (que decide para onde navegar) terminar,
    // pra não sobrar Timer pendente no fim do teste.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('StudyScreen mostra botões de autoavaliação e envia resposta',
      (WidgetTester tester) async {
    final requests = <String>[];
    final originalClient = ApiService.client;

    // Substitui o client HTTP do ApiService por um MockClient: ele responde
    // na hora, sem abrir socket nenhum. Isso importa porque testWidgets roda
    // dentro de um relógio "fake" (FakeAsync) -- uma requisição de rede de
    // verdade (ex: um HttpServer local de teste) nunca chega a completar
    // aí dentro e o teste trava para sempre esperando a resposta.
    ApiService.client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');

      Map<String, dynamic>? body;
      if (request.method == 'GET' && request.url.path == '/decks/1') {
        body = {
          'id': 1,
          'nome': 'Matemática',
          'user_id': 1,
          'cards': [
            {'id': 10, 'pergunta': '2 + 2', 'resposta': '4', 'deck_id': 1},
          ],
        };
      } else if (request.method == 'POST' &&
          request.url.path == '/study-sessions') {
        body = {
          'id': 99,
          'user_id': 1,
          'deck_id': 1,
          'acertos': 0,
          'erros': 0,
          'iniciado_em': '2026-09-07T00:00:00.000Z',
          'finalizado_em': null,
        };
      } else if (request.method == 'POST' &&
          request.url.path == '/study-sessions/99/responder') {
        body = {
          'id': 99,
          'user_id': 1,
          'deck_id': 1,
          'acertos': 1,
          'erros': 0,
          'iniciado_em': '2026-09-07T00:00:00.000Z',
          'finalizado_em': null,
        };
      } else if (request.method == 'PUT' &&
          request.url.path == '/study-sessions/99/finalizar') {
        body = {
          'msg': 'Sessão de estudo finalizada',
          'finalizado_em': '2026-09-07T00:10:00.000Z',
        };
      }

      if (body == null) {
        return http.Response('', 404);
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    try {
      await tester.pumpWidget(MaterialApp(home: StudyScreen(deckId: 1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Os botões "Acertei"/"Errei" só aparecem depois que o card é virado
      // (StudyScreen só mostra "Toque para virar" antes disso), então
      // precisamos simular esse toque antes de procurar pelos botões. O
      // texto "Toque para virar" é IRMÃO do GestureDetector do card (não
      // filho), então tocar nele não vira o card -- por isso tocamos no
      // próprio conteúdo do card (a pergunta), que fica dentro do
      // GestureDetector.
      expect(find.text('2 + 2'), findsOneWidget);
      await tester.tap(find.text('2 + 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // duração do flip

      expect(find.text('Acertei'), findsOneWidget);
      expect(find.text('Errei'), findsOneWidget);

      await tester.tap(find.text('Acertei'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(requests, contains('POST /study-sessions'));
      expect(requests, contains('POST /study-sessions/99/responder'));
    } finally {
      // Restaura o client real pra não vazar o mock pra outros testes.
      ApiService.client = originalClient;
    }
  });
}
