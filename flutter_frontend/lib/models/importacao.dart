// Models da importação (RF11 arquivo / RF12 foto).
// O backend lê o arquivo e devolve uma PRÉVIA; o usuário revisa na tela
// de prévia e só então os cards são gravados.

// Um par pergunta/resposta encontrado no arquivo ou na foto.
// `incluir` é o checkbox da prévia (desmarcado = não importa).
class CardImportado {
  String pergunta;
  String resposta;
  bool incluir;

  CardImportado({
    required this.pergunta,
    required this.resposta,
    this.incluir = true,
  });

  factory CardImportado.fromJson(Map<String, dynamic> json) => CardImportado(
        pergunta: json['pergunta'] as String,
        resposta: json['resposta'] as String,
      );

  Map<String, dynamic> toJson() => {'pergunta': pergunta, 'resposta': resposta};
}

// Resposta do POST /importar/previa.
class PreviaImportacao {
  final String nomeSugerido;
  final String origem; // anki | texto | excel | pdf | foto
  final List<CardImportado> cards;
  final int ignoradas; // linhas com conteúdo que não viraram card
  final List<String> avisos;

  PreviaImportacao({
    required this.nomeSugerido,
    required this.origem,
    required this.cards,
    required this.ignoradas,
    required this.avisos,
  });

  factory PreviaImportacao.fromJson(Map<String, dynamic> json) =>
      PreviaImportacao(
        nomeSugerido: json['nome_sugerido'] as String? ?? 'Deck importado',
        origem: json['origem'] as String? ?? '',
        cards: (json['cards'] as List? ?? [])
            .map((c) => CardImportado.fromJson(c as Map<String, dynamic>))
            .toList(),
        ignoradas: json['ignoradas'] as int? ?? 0,
        avisos: (json['avisos'] as List? ?? []).cast<String>(),
      );
}
