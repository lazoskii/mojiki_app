// Testes da importação (RF11 arquivo / RF12 foto) do lado do app:
// envio do arquivo pro backend e a tela de revisão (prévia).
// A leitura dos formatos em si é testada no backend (backend/test_backend.py).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mojiki/models/deck.dart';
import 'package:mojiki/models/importacao.dart';
import 'package:mojiki/screens/previa_importacao_screen.dart';
import 'package:mojiki/services/api_service.dart';
import 'package:mojiki/widgets/importar.dart';

http.Response _json(Object corpo, [int status = 200]) => http.Response(
    jsonEncode(corpo), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

PreviaImportacao _previa() => PreviaImportacao(
      nomeSugerido: 'Vocabulário',
      origem: 'pdf',
      ignoradas: 2,
      avisos: ['O PDF não tem texto (parece escaneado)'],
      cards: [
        CardImportado(pergunta: '水', resposta: 'água'),
        CardImportado(pergunta: '火', resposta: 'fogo'),
        CardImportado(pergunta: 'Lição 1', resposta: 'título'),
      ],
    );

void main() {
  late http.Client original;
  final requisicoes = <String, dynamic>{};

  setUp(() {
    original = ApiService.client;
    requisicoes.clear();
  });
  tearDown(() => ApiService.client = original);

  void telaDeCelular(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  test('previaImportacao envia o arquivo (multipart) e lê a prévia', () async {
    ApiService.client = MockClient((req) async {
      requisicoes['rota'] = '${req.method} ${req.url.path}';
      requisicoes['tipo'] = req.headers['content-type'];
      requisicoes['corpo'] = utf8.decode(req.bodyBytes, allowMalformed: true);
      return _json({
        'nome_sugerido': 'vocab',
        'origem': 'texto',
        'cards': [
          {'pergunta': '水', 'resposta': 'água'}
        ],
        'ignoradas': 0,
        'avisos': [],
      });
    });

    final previa = await ApiService.previaImportacao(
        bytes: Uint8List.fromList(utf8.encode('水;água')),
        nomeArquivo: 'vocab.csv');

    expect(requisicoes['rota'], 'POST /importar/previa');
    expect(requisicoes['tipo'], startsWith('multipart/form-data'));
    expect(requisicoes['corpo'], contains('filename="vocab.csv"'));
    expect(previa.cards.single.resposta, 'água'); // acento intacto (UTF-8)
  });

  test('previaDeTexto manda o texto lido no aparelho (OCR local)', () async {
    ApiService.client = MockClient((req) async {
      requisicoes['rota'] = '${req.method} ${req.url.path}';
      requisicoes['json'] = jsonDecode(req.body);
      return _json({
        'nome_sugerido': 'Deck da foto',
        'origem': 'foto',
        'cards': [
          {'pergunta': '水', 'resposta': 'água'}
        ],
        'ignoradas': 1,
        'avisos': [],
      });
    });

    final previa = await ApiService.previaDeTexto('Lição 1\n水 - água');

    expect(requisicoes['rota'], 'POST /importar/texto');
    expect(requisicoes['json'], {'texto': 'Lição 1\n水 - água'});
    expect(previa.origem, 'foto');
    expect(previa.ignoradas, 1);
  });

  test('erro do backend (ex.: Tesseract ausente) vira mensagem legível', () async {
    ApiService.client = MockClient((_) async =>
        _json({'detail': 'Leitura de fotos indisponível'}, 400));
    expect(
      () => ApiService.previaImportacao(
          bytes: Uint8List(3), nomeArquivo: 'foto.jpg'),
      throwsA(isA<ApiException>().having(
          (e) => e.message, 'mensagem', 'Leitura de fotos indisponível')),
    );
  });

  testWidgets('prévia: desmarca, inverte e importa só os marcados',
      (tester) async {
    telaDeCelular(tester);
    ApiService.client = MockClient((req) async {
      requisicoes['rota'] = '${req.method} ${req.url.path}';
      requisicoes['json'] = jsonDecode(req.body);
      return _json({'id': 7, 'nome': 'Natureza', 'user_id': 1, 'total_cards': 2});
    });

    ResultadoImportacao? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              resultado = await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PreviaImportacaoScreen(previa: _previa())));
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('3 cards encontrados · 2 linhas ignoradas'), findsOneWidget);
    expect(find.text('O PDF não tem texto (parece escaneado)'), findsOneWidget);
    expect(find.text('Importar 3 cards'), findsOneWidget);

    await tester.tap(find.text('Lição 1')); // desmarca a linha errada
    await tester.pump();
    expect(find.text('Importar 2 cards'), findsOneWidget);

    await tester.tap(find.text('Inverter pergunta/resposta'));
    await tester.pump();
    await tester.tap(find.text('Inverter pergunta/resposta')); // volta
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Natureza');
    await tester.tap(find.text('Importar 2 cards'));
    await tester.pumpAndSettle();

    expect(requisicoes['rota'], 'POST /decks/importar');
    expect(requisicoes['json']['nome'], 'Natureza');
    expect(requisicoes['json']['cards'], [
      {'pergunta': '水', 'resposta': 'água'},
      {'pergunta': '火', 'resposta': 'fogo'},
    ]);
    expect(resultado?.deckNovo?.totalCards, 2);
  });

  testWidgets('prévia sem nome de deck não importa', (tester) async {
    telaDeCelular(tester);
    var chamou = false;
    ApiService.client = MockClient((_) async {
      chamou = true;
      return _json({});
    });

    await tester.pumpWidget(
        MaterialApp(home: PreviaImportacaoScreen(previa: _previa())));
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.tap(find.text('Importar 3 cards'));
    await tester.pump();

    expect(find.text('Digite um nome para o deck.'), findsOneWidget);
    expect(chamou, isFalse);
  });

  testWidgets('foto dentro de um deck adiciona os cards nele', (tester) async {
    telaDeCelular(tester);
    ApiService.client = MockClient((req) async {
      requisicoes['rota'] = '${req.method} ${req.url.path}';
      return _json([
        {'id': 50, 'pergunta': '水', 'resposta': 'água', 'deck_id': 3},
      ]);
    });
    final previa = PreviaImportacao(
        nomeSugerido: 'Deck da foto',
        origem: 'foto',
        ignoradas: 0,
        avisos: const [],
        cards: [CardImportado(pergunta: '水', resposta: 'água')]);

    await tester.pumpWidget(MaterialApp(
        home: PreviaImportacaoScreen(
            previa: previa,
            deckDestino: Deck(id: 3, nome: 'Natureza', userId: 1))));

    expect(find.text('Os cards vão para "Natureza"'), findsOneWidget);
    await tester.tap(find.text('Importar 1 card'));
    await tester.pumpAndSettle();
    expect(requisicoes['rota'], 'POST /decks/3/flashcards/lote');
  });
}
