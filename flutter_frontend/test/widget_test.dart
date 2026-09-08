// Smoke test básico: garante que o app sobe sem lançar exceções e que a
// tela inicial (Splash) é exibida.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojiki/main.dart';
import 'package:mojiki/screens/study_screen.dart';

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
    late HttpServer server;
    final requests = <String>[];

    HttpOverrides.runZoned(() async {
      server = await HttpServer.bind('127.0.0.1', 0);
      final port = server.port;

      server.listen((request) async {
        requests.add('${request.method} ${request.uri.path}');

        if (request.method == 'GET' && request.uri.path == '/decks/1') {
          final body = jsonEncode({
            'id': 1,
            'nome': 'Matemática',
            'user_id': 1,
            'cards': [
              {'id': 10, 'pergunta': '2 + 2', 'resposta': '4', 'deck_id': 1},
            ],
          });
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(body);
          await request.response.close();
          return;
        }

        if (request.method == 'POST' && request.uri.path == '/study-sessions') {
          final body = jsonEncode({
            'id': 99,
            'user_id': 1,
            'deck_id': 1,
            'acertos': 0,
            'erros': 0,
            'iniciado_em': '2026-09-07T00:00:00.000Z',
            'finalizado_em': null,
          });
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(body);
          await request.response.close();
          return;
        }

        if (request.method == 'POST' && request.uri.path == '/study-sessions/99/responder') {
          final body = jsonEncode({
            'id': 99,
            'user_id': 1,
            'deck_id': 1,
            'acertos': 1,
            'erros': 0,
            'iniciado_em': '2026-09-07T00:00:00.000Z',
            'finalizado_em': null,
          });
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(body);
          await request.response.close();
          return;
        }

        if (request.method == 'PUT' && request.uri.path == '/study-sessions/99/finalizar') {
          final body = jsonEncode({'msg': 'Sessão de estudo finalizada', 'finalizado_em': '2026-09-07T00:10:00.000Z'});
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(body);
          await request.response.close();
          return;
        }

        request.response.statusCode = 404;
        await request.response.close();
      });

      final uri = Uri.parse('http://127.0.0.1:${server.port}');
      HttpOverrides.global = _TestHttpOverrides(uri);

      await tester.pumpWidget(MaterialApp(home: StudyScreen(deckId: 1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Acertei'), findsOneWidget);
      expect(find.text('Errei'), findsOneWidget);

      await tester.tap(find.text('Acertei'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(requests, contains('POST /study-sessions'));
      expect(requests, contains('POST /study-sessions/99/responder'));
    }, (error, stackTrace) {
      // no-op: o teste vai falhar normalmente em caso de erro
    });

    await server.close();
    HttpOverrides.global = null;
  });
}

class _TestHttpOverrides extends HttpOverrides {
  _TestHttpOverrides(this.baseUri);

  final Uri baseUri;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    return _ClientAdapter(client, baseUri);
  }
}

class _ClientAdapter implements HttpClient {
  _ClientAdapter(this._inner, this._baseUri);

  final HttpClient _inner;
  final Uri _baseUri;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get || invocation.memberName == #post || invocation.memberName == #put || invocation.memberName == #delete) {
      final args = invocation.positionalArguments;
      final uri = args.first as Uri;
      final rewritten = uri.replace(
        scheme: _baseUri.scheme,
        host: _baseUri.host,
        port: _baseUri.port,
      );
      return Function.apply(
        () => _inner.invoke(invocation.memberName.toString(), [rewritten, if (args.length > 1) args[1]]),
        [],
      );
    }
    return _inner.invoke(invocation.memberName.toString(), []);
  }
}
