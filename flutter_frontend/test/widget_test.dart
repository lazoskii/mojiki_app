// Smoke test básico: garante que o app sobe sem lançar exceções e que a
// tela inicial (Splash) é exibida.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mojiki/main.dart';

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
}
