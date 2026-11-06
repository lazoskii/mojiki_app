import 'package:flutter/material.dart';

// Modos de estudo (Bloco 6 / RF08). Cada modo é só um conjunto de regras:
// - duracao: tempo máximo da sessão (quando acaba, a sessão é finalizada)
// - limiteCards: quantos cards entram no máximo (null = todos)
// - repeteErros: card marcado como "Errei" volta pro fim da fila
// Os cards sempre são embaralhados quando a sessão é de um modo.
enum ModoEstudo {
  rapida(
    titulo: 'Sessão Rápida',
    descricao: 'Até 10 cards em 5 minutos',
    duracao: Duration(minutes: 5),
    limiteCards: 10,
    repeteErros: false,
    icone: Icons.flash_on,
    cores: [Color(0xFFEAB308), Color(0xFFC2410C)],
  ),
  diaria(
    titulo: 'Prática Diária',
    descricao: 'Todos os cards em 15 minutos',
    duracao: Duration(minutes: 15),
    limiteCards: null,
    repeteErros: false,
    icone: Icons.track_changes,
    cores: [Color(0xFFDC2626), Color(0xFFB91C1C)],
  ),
  intensiva(
    titulo: 'Sessão Intensiva',
    descricao: '30 minutos — cards errados voltam pro fim',
    duracao: Duration(minutes: 30),
    limiteCards: null,
    repeteErros: true,
    icone: Icons.access_time,
    cores: [Color(0xFF9333EA), Color(0xFF7F1D1D)],
  );

  const ModoEstudo({
    required this.titulo,
    required this.descricao,
    required this.duracao,
    required this.limiteCards,
    required this.repeteErros,
    required this.icone,
    required this.cores,
  });

  final String titulo;
  final String descricao;
  final Duration duracao;
  final int? limiteCards;
  final bool repeteErros;
  final IconData icone;
  final List<Color> cores;

  // o "name" do enum (rapida/diaria/intensiva) é o que vai pra URL e pro backend
  static ModoEstudo? deNome(String? nome) {
    for (final modo in values) {
      if (modo.name == nome) return modo;
    }
    return null;
  }
}
