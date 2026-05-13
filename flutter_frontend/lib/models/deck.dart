import 'flashcard.dart';

class Deck {
  final int id;
  final String nome;
  final int userId;
  final List<Flashcard> cards;

  Deck({
    required this.id,
    required this.nome,
    required this.userId,
    this.cards = const [],
  });

  // fromJson: converte o JSON da API em um objeto Deck
  // equivale a quando você fazia: const data = await res.json()
  factory Deck.fromJson(Map<String, dynamic> json) {
    return Deck(
      id: json['id'],
      nome: json['nome'],
      userId: json['user_id'] ?? 1,
      cards: json['cards'] != null
          ? (json['cards'] as List).map((c) => Flashcard.fromJson(c)).toList()
          : [],
    );
  }

  // toJson: converte o objeto em Map para enviar na requisição POST
  Map<String, dynamic> toJson() => {
        'nome': nome,
        'user_id': userId,
      };
}
