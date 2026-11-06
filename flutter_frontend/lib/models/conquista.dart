import 'package:flutter/material.dart';

// Conquista = um selinho que o usuário desbloqueia quando bate uma meta
// simples. Cada uma só compara um número guardado (cards estudados,
// sequência de dias, total de acertos) com um limiar fixo — sem estado
// próprio pra salvar, dá pra explicar como "se stat >= meta, desbloqueou".
class Conquista {
  final String titulo;
  final String descricao;
  final IconData icon;
  final bool Function(
          {required int cardsStudied,
          required int streak,
          required int totalAcertos})
      desbloqueada;

  const Conquista({
    required this.titulo,
    required this.descricao,
    required this.icon,
    required this.desbloqueada,
  });
}

final conquistas = <Conquista>[
  Conquista(
    titulo: 'Primeiros Passos',
    descricao: 'Estude seu primeiro flashcard',
    icon: Icons.school,
    desbloqueada: ({required cardsStudied, required streak, required totalAcertos}) =>
        cardsStudied >= 1,
  ),
  Conquista(
    titulo: 'Dedicado',
    descricao: 'Estude 50 flashcards',
    icon: Icons.menu_book,
    desbloqueada: ({required cardsStudied, required streak, required totalAcertos}) =>
        cardsStudied >= 50,
  ),
  Conquista(
    titulo: 'Em Chamas',
    descricao: 'Mantenha uma sequência de 3 dias',
    icon: Icons.local_fire_department,
    desbloqueada: ({required cardsStudied, required streak, required totalAcertos}) =>
        streak >= 3,
  ),
  Conquista(
    titulo: 'Mestre dos Acertos',
    descricao: 'Acerte 20 flashcards na autoavaliação',
    icon: Icons.military_tech,
    desbloqueada: ({required cardsStudied, required streak, required totalAcertos}) =>
        totalAcertos >= 20,
  ),
];
