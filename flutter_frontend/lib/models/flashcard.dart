class Flashcard {
  final int id;
  final String pergunta;
  final String resposta;
  final int deckId;

  Flashcard({
    required this.id,
    required this.pergunta,
    required this.resposta,
    required this.deckId,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'],
      pergunta: json['pergunta'],
      resposta: json['resposta'],
      deckId: json['deck_id'],
    );
  }

  Map<String, dynamic> toJson() => {
        'pergunta': pergunta,
        'resposta': resposta,
        'deck_id': deckId,
      };
}
