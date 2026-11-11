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
    cor: Color(0xFFB45309),
    corClara: Color(0xFFFDF3D7),
  ),
  diaria(
    titulo: 'Prática Diária',
    descricao: 'Todos os cards em 15 minutos',
    duracao: Duration(minutes: 15),
    limiteCards: null,
    repeteErros: false,
    icone: Icons.track_changes,
    cor: Color(0xFFD1283A),
    corClara: Color(0xFFFCE9EB),
  ),
  intensiva(
    titulo: 'Sessão Intensiva',
    descricao: '30 minutos — cards errados voltam pro fim',
    duracao: Duration(minutes: 30),
    limiteCards: null,
    repeteErros: true,
    icone: Icons.access_time,
    cor: Color(0xFF7E22CE),
    corClara: Color(0xFFF1E8FB),
  );

  const ModoEstudo({
    required this.titulo,
    required this.descricao,
    required this.duracao,
    required this.limiteCards,
    required this.repeteErros,
    required this.icone,
    required this.cor,
    required this.corClara,
  });

  final String titulo;
  final String descricao;
  final Duration duracao;
  final int? limiteCards;
  final bool repeteErros;
  final IconData icone;
  // cor do ícone do modo e o fundo claro do quadradinho atrás dele
  final Color cor;
  final Color corClara;

  // o "name" do enum (rapida/diaria/intensiva) é o que vai pra URL e pro backend
  static ModoEstudo? deNome(String? nome) {
    for (final modo in values) {
      if (modo.name == nome) return modo;
    }
    return null;
  }
}
