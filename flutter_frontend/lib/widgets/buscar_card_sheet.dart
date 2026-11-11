import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../utils/busca.dart';
import 'campo_busca.dart';

// Busca de cards dentro de um deck (Bloco 7). Abre um painel com campo de
// busca (procura na pergunta E na resposta) e devolve a POSIÇÃO do card
// escolhido na lista da sessão, ou null se fechar sem escolher.
Future<int?> mostrarBuscaCards(BuildContext context, List<Flashcard> cards) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true, // deixa o painel subir junto com o teclado
    builder: (_) => _BuscaCardsSheet(cards: cards),
  );
}

class _BuscaCardsSheet extends StatefulWidget {
  final List<Flashcard> cards;
  const _BuscaCardsSheet({required this.cards});

  @override
  State<_BuscaCardsSheet> createState() => _BuscaCardsSheetState();
}

class _BuscaCardsSheetState extends State<_BuscaCardsSheet> {
  final _controller = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Na Sessão Intensiva um card errado aparece de novo no fim da fila;
    // aqui cada card entra uma vez só (a primeira posição dele).
    final vistos = <int>{};
    final resultados = <({int posicao, Flashcard card})>[];
    for (var i = 0; i < widget.cards.length; i++) {
      final card = widget.cards[i];
      if (!vistos.add(card.id)) continue;
      if (combinaBusca(_busca, [card.pergunta, card.resposta])) {
        resultados.add((posicao: i, card: card));
      }
    }

    return Padding(
      // empurra o conteúdo pra cima do teclado
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Buscar card',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CampoBusca(
                controller: _controller,
                dica: 'Pergunta ou resposta',
                autofocus: true,
                onChanged: (texto) => setState(() => _busca = texto),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: resultados.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Nenhum card encontrado',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: resultados.length,
                      itemBuilder: (context, i) {
                        final r = resultados[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            child: Text('${r.posicao + 1}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ),
                          title: Text(r.card.pergunta,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(r.card.resposta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white60)),
                          onTap: () => Navigator.of(context).pop(r.posicao),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
