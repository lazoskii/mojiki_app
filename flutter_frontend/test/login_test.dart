// Testes da tela de login: regras da senha no cadastro e token salvo ao entrar.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mojiki/screens/login_screen.dart';
import 'package:mojiki/services/api_service.dart';
import 'package:mojiki/services/auth_service.dart';
import 'package:mojiki/utils/validacao_login.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Abre a tela de login dentro de um go_router mínimo (ela usa context.go)
Widget _app() => MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/login', routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/home', builder: (_, _) => const Text('HOME')),
      ]),
    );

void main() {
  test('regras da senha: 8 caracteres, um número e uma maiúscula', () {
    expect(validarSenha('Abc123'), contains('8 caracteres'));
    expect(validarSenha('Abcdefgh'), contains('número'));
    expect(validarSenha('abcdefg1'), contains('maiúscula'));
    expect(validarSenha('Japones2026'), isNull);
  });

  testWidgets('cadastro recusa senha fraca sem chamar o servidor', (tester) async {
    var chamadas = 0;
    ApiService.client = MockClient((_) async {
      chamadas++;
      return http.Response('{}', 200);
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.tap(find.text('Criar conta').first); // seletor
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'ana');
    await tester.enterText(find.byType(TextField).at(1), 'ana@x.com');
    await tester.enterText(find.byType(TextField).at(2), 'semnumero');
    await tester.enterText(find.byType(TextField).at(3), 'semnumero');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.pump();

    expect(find.text('A senha precisa ter pelo menos um número'), findsOneWidget);
    expect(chamadas, 0);
  });

  testWidgets('entrar salva o token e vai pra Home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiService.client = MockClient((req) async {
      expect(req.url.path, '/auth/login');
      return http.Response(
          jsonEncode({'token': 'abc', 'id': 1, 'usuario': 'ana', 'email': 'a@x.com'}), 200);
    });

    await tester.pumpWidget(_app());
    await tester.enterText(find.byType(TextField).at(0), 'ana');
    await tester.enterText(find.byType(TextField).at(1), 'Senha123');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(AuthService.token, 'abc');
    await AuthService.limpar();
  });
}
