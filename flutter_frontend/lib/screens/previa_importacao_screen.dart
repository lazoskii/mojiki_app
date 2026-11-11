import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../models/importacao.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_campo.dart';
import '../widgets/importar.dart';

// Tela de revisão da importação (RF11/RF12). O backend leu o arquivo ou a
// foto e devolveu os pares que achou; aqui o usuário:
//   - escolhe o nome do deck (quando é um deck novo);
//   - desmarca o que não quer, edita um card, ou inverte pergunta/resposta;
//   - toca em "Importar N cards" — só então os cards são gravados.
// Revisar é importante porque PDF e foto usam reconhecimento automático
// (japonês x português), que pode errar.
class PreviaImportacaoScreen extends StatefulWidget {
  final PreviaImportacao previa;
  final Deck? deckDestino; // null = cria deck novo

  const PreviaImportacaoScreen({
    super.key,
    required this.previa,
    this.deckDestino,
  });

  @override
  State<PreviaImportacaoScreen> createState() => _PreviaImportacaoScreenState();
}

class _PreviaImportacaoScreenState extends State<PreviaImportacaoScreen> {
  late final _nomeController =
      TextEditingController(text: widget.previa.nomeSugerido);
  final _formKey = GlobalKey<FormState>();
  late final List<CardImportado> _cards = widget.previa.cards;
  var _salvando = false;

  List<CardImportado> get _selecionados =>
      _cards.where((c) => c.incluir).toList();

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  // Troca pergunta <-> resposta em todos os cards (ex.: planilha que veio
  // com o português na primeira coluna).
  void _inverterTodos() {
    setState(() {
      for (final c in _cards) {
        final p = c.pergunta;
        c.pergunta = c.resposta;
        c.resposta = p;
      }
    });
  }

  void _marcarTodos(bool marcar) {
    setState(() {
      for (final c in _cards) {
        c.incluir = marcar;
      }
    });
  }

  Future<void> _editar(CardImportado card) async {
    final mudou = await showDialog<bool>(
      context: context,
      builder: (_) => _EditarCardImportado(card: card),
    );
    if (mudou == true) setState(() {});
  }

  Future<void> _importar() async {
    if (widget.deckDestino == null && !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _salvando = true);
    try {
      final ResultadoImportacao resultado;
      if (widget.deckDestino == null) {
        final deck = await ApiService.importarDeck(
            nome: _nomeController.text.trim(), cards: _selecionados);
        resultado = ResultadoImportacao(deckNovo: deck);
      } else {
        final cards = await ApiService.adicionarCards(
            deckId: widget.deckDestino!.id, cards: _selecionados);
        resultado = ResultadoImportacao(cardsAdicionados: cards);
      }
      if (!mounted) return;
      Navigator.of(context).pop(resultado);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final previa = widget.previa;
    final selecionados = _selecionados.length;
    final todosMarcados = selecionados == _cards.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar importação'),
        backgroundColor: AppColors.fundo,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (widget.deckDestino == null)
              AppCampo(
                controller: _nomeController,
                rotulo: 'Nome do deck',
                validator: (t) =>
                    t.trim().isEmpty ? 'Digite um nome para o deck.' : null,
              )
            else
              Text('Os cards vão para "${widget.deckDestino!.nome}"',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Resumo do que foi encontrado
            Text(
              '${_cards.length} ${_cards.length == 1 ? 'card encontrado' : 'cards encontrados'}'
              '${previa.ignoradas > 0 ? ' · ${previa.ignoradas} linhas ignoradas' : ''}',
              style: const TextStyle(color: AppColors.textoSuave),
            ),

            // Avisos do backend (PDF escaneado, sem japonês no OCR, limite...)
            for (final aviso in previa.avisos)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF3D7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: Color(0xFF92400E)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(aviso,
                            style: const TextStyle(color: Color(0xFF78350F)))),
                  ],
                ),
              ),

            if (_cards.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _inverterTodos,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Inverter pergunta/resposta'),
                  ),
                  TextButton(
                    onPressed: () => _marcarTodos(!todosMarcados),
                    child: Text(todosMarcados ? 'Desmarcar todos' : 'Marcar todos'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final card in _cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CardPrevia(
                    card: card,
                    onMarcar: (v) => setState(() => card.incluir = v),
                    onEditar: () => _editar(card),
                  ),
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: selecionados == 0 || _salvando ? null : _importar,
            child: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(selecionados == 0
                    ? 'Nenhum card selecionado'
                    : 'Importar $selecionados ${selecionados == 1 ? 'card' : 'cards'}'),
          ),
        ),
      ),
    );
  }
}

// Uma linha da prévia: checkbox + pergunta/resposta + editar
class _CardPrevia extends StatelessWidget {
  final CardImportado card;
  final ValueChanged<bool> onMarcar;
  final VoidCallback onEditar;

  const _CardPrevia({
    required this.card,
    required this.onMarcar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: card.incluir ? AppColors.superficie : const Color(0xFFF1ECEA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.linha),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onMarcar(!card.incluir),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: card.incluir,
                onChanged: (v) => onMarcar(v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.pergunta,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: card.incluir
                                ? AppColors.texto
                                : AppColors.textoSuave)),
                    Text(card.resposta,
                        style: const TextStyle(color: AppColors.textoSuave)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEditar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Edição local de um card da prévia (ainda não foi pro backend).
class _EditarCardImportado extends StatefulWidget {
  final CardImportado card;
  const _EditarCardImportado({required this.card});

  @override
  State<_EditarCardImportado> createState() => _EditarCardImportadoState();
}

class _EditarCardImportadoState extends State<_EditarCardImportado> {
  late final _pergunta = TextEditingController(text: widget.card.pergunta);
  late final _resposta = TextEditingController(text: widget.card.resposta);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _pergunta.dispose();
    _resposta.dispose();
    super.dispose();
  }

  String? _obrigatorio(String t) => t.trim().isEmpty ? 'Campo obrigatório' : null;

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;
    widget.card
      ..pergunta = _pergunta.text.trim()
      ..resposta = _resposta.text.trim()
      ..incluir = true;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar card'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppCampo(
                controller: _pergunta,
                rotulo: 'Pergunta',
                autofocus: true,
                validator: _obrigatorio),
            const SizedBox(height: 16),
            AppCampo(
                controller: _resposta,
                rotulo: 'Resposta',
                validator: _obrigatorio,
                onSubmitted: (_) => _salvar()),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
