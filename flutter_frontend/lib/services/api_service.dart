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

class ApiService {
  // ========================
  // DECKS
  // ========================

  static Future<List<Deck>> listarDecks() async {
    final res = await http.get(Uri.parse('$_baseUrl/decks'));
    final List data = jsonDecode(res.body);
    return data.map((d) => Deck.fromJson(d)).toList();
  }

  static Future<Deck> buscarDeck(int id) async {
    final res = await http.get(Uri.parse('$_baseUrl/decks/$id'));
    return Deck.fromJson(jsonDecode(res.body));
  }

  static Future<Deck> criarDeck(String nome) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/decks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nome': nome, 'user_id': 1}),
    );
    return Deck.fromJson(jsonDecode(res.body));
  }

  static Future<void> deletarDeck(int id) async {
    await http.delete(Uri.parse('$_baseUrl/decks/$id'));
  }

  // ========================
  // FLASHCARDS
  // ========================

  static Future<Flashcard> criarFlashcard({
    required String pergunta,
    required String resposta,
    required int deckId,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/flashcards'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pergunta': pergunta,
        'resposta': resposta,
        'deck_id': deckId,
      }),
    );
    return Flashcard.fromJson(jsonDecode(res.body));
  }

  static Future<void> deletarFlashcard(int id) async {
    await http.delete(Uri.parse('$_baseUrl/flashcards/$id'));
  }
}
