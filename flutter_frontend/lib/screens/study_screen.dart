import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/deck.dart';
import '../models/modo_estudo.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
import '../widgets/app_campo.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/buscar_card_sheet.dart';
import '../widgets/edit_flashcard_dialog.dart';
import '../widgets/error_retry.dart';
import '../widgets/importar.dart';
import '../widgets/session_results_dialog.dart';
import '../theme/app_theme.dart';

// Tela de estudo de um deck: mostra um card por vez, vira com um toque e
// registra a autoavaliação (Acertei/Errei). Também cria, edita, exclui e
// busca cards, e aplica as regras dos modos de estudo (cronômetro etc.).
//
// Como a tela conversa com o servidor sem "engasgar":
//   a tela muda NA HORA (placar, próximo card) e o que precisa ir pro
//   backend entra numa fila (_filaServidor) que roda em segundo plano, na
//   ordem: criar sessão → registrar respostas → finalizar sessão.
class StudyScreen extends StatefulWidget {
  final int deckId;
  final ModoEstudo? modo; // null = deck aberto direto da Home (estudo livre)
  final String voltarPara; // aba de onde veio (botão "voltar")

  const StudyScreen({
    super.key,
    required this.deckId,
    this.modo,
    this.voltarPara = '/home',
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  // ---- dados do deck e posição atual ----
  Deck? _deck; // no modo, os cards já vêm embaralhados/limitados
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _loading = true;
  String? _error;

  // ---- autoavaliação (Acertei / Errei) ----
  int? _sessaoId;
  int _acertos = 0;
  int _erros = 0;
  // fila de chamadas ao backend, executadas uma depois da outra
  Future<void> _filaServidor = Future.value();
  bool _avisouFalha = false; // mostra o aviso de falha de rede uma vez só
  // cards já contados como "estudados" nesta sessão (virar o mesmo card
  // várias vezes contava várias vezes no Progresso)
  final _cardsContados = <int>{};

  // ---- modos de estudo (Bloco 6): cronômetro ----
  Timer? _timer;
  // ValueNotifier: só o chip do cronômetro redesenha a cada segundo, não a
  // tela inteira (antes o setState por segundo redesenhava tudo)
  final _restante = ValueNotifier<Duration>(Duration.zero);
  bool _encerrada = false; // evita finalizar duas vezes (último card + tempo)

  // ---- animação de virar o card ----
  // AnimationController = controla animações (equivale ao framer-motion)
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  final _perguntaController = TextEditingController();
  final _respostaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Configura a animação de virar o card (180 graus)
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _carregarDeck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restante.dispose();
    _flipController.dispose();
    _perguntaController.dispose();
    _respostaController.dispose();
    super.dispose();
  }

  // Busca o deck na API, aplica as regras do modo e começa a sessão.
  Future<void> _carregarDeck() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deck = await ApiService.buscarDeck(widget.deckId);
      if (!mounted) return;
      setState(() {
        _deck = _aplicarModo(deck);
        _loading = false;
      });
      ProgressService.salvarUltimoDeck(deck.id); // atalho da Home
      _iniciarTimer();
      _iniciarSessao();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Regras do modo: embaralha e corta no limite de cards (Sessão Rápida).
  Deck _aplicarModo(Deck deck) {
    final modo = widget.modo;
    if (modo == null) return deck;

    var cards = [...deck.cards]..shuffle();
    if (modo.limiteCards != null && cards.length > modo.limiteCards!) {
      cards = cards.take(modo.limiteCards!).toList();
    }
    return Deck(id: deck.id, nome: deck.nome, userId: deck.userId, cards: cards);
  }

  // Cronômetro regressivo do modo; quando zera, a sessão é finalizada.
  void _iniciarTimer() {
    _timer?.cancel();
    final modo = widget.modo;
    if (modo == null || _deck!.cards.isEmpty) return;

    _restante.value = modo.duracao;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      _restante.value -= const Duration(seconds: 1);
      if (_restante.value <= Duration.zero) {
        timer.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tempo esgotado!')),
        );
        _finalizarSessao();
      }
    });
  }

  String _formatarTempo(Duration d) {
    final min = d.inMinutes.toString().padLeft(2, '0');
    final seg = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$seg';
  }

  void _mostrarErro(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }

  // Coloca uma chamada ao backend no fim da fila. Se falhar, a tela segue
  // funcionando (placar local) e avisa uma vez que não conseguiu salvar.
  void _naFila(Future<void> Function() chamada) {
    _filaServidor = _filaServidor.then((_) => chamada()).catchError((e) {
      debugPrint('Falha ao falar com o servidor: $e');
      if (mounted && !_avisouFalha) {
        _avisouFalha = true;
        _mostrarErro('Sem conexão: o resultado desta sessão pode não ser salvo.');
      }
    });
  }

  void _iniciarSessao() {
    _naFila(() async {
      // zera DENTRO da fila: a finalização da sessão anterior (que está na
      // frente dela) ainda precisa do id antigo
      _sessaoId = null;
      final sessao = await ApiService.iniciarSessao(
        userId: usuarioFixoId, // pendência: ver api_service.dart
        deckId: widget.deckId,
        modo: widget.modo?.name,
      );
      _sessaoId = sessao['id'];
    });
  }

  // Autoavaliação: atualiza placar e avança NA HORA; o registro no backend
  // vai pra fila. (Antes a tela esperava a rede responder e os botões
  // ficavam desativados nesse meio-tempo — era o "engasgo".)
  void _responder(bool acerto) {
    // !_isFlipped: segundo toque rápido no mesmo botão é ignorado (o card
    // já avançou e voltou pra frente)
    if (_encerrada || !_isFlipped || _deck!.cards.isEmpty) return;
    HapticFeedback.selectionClick();

    setState(() {
      if (acerto) {
        _acertos++;
      } else {
        _erros++;
        // Sessão Intensiva: card errado volta pro fim da fila
        if (widget.modo?.repeteErros ?? false) {
          _deck = Deck(
            id: _deck!.id,
            nome: _deck!.nome,
            userId: _deck!.userId,
            cards: [..._deck!.cards, _deck!.cards[_currentIndex]],
          );
        }
      }
    });

    if (acerto) ProgressService.registrarAcerto(); // XP (local)
    _naFila(() async {
      final id = _sessaoId;
      if (id == null) return; // sessão não foi criada (sem conexão)
      await ApiService.registrarResposta(sessaoId: id, acerto: acerto);
    });

    final ultimoCard = _currentIndex >= _deck!.cards.length - 1;
    if (ultimoCard) {
      _finalizarSessao();
    } else {
      _proximo();
    }
  }

  // Fim da sessão (último card ou tempo esgotado): fecha no backend depois
  // que as respostas da fila foram registradas e mostra o resultado.
  Future<void> _finalizarSessao() async {
    if (_encerrada) return;
    _encerrada = true;
    _timer?.cancel();

    _naFila(() async {
      final id = _sessaoId;
      if (id != null) await ApiService.finalizarSessao(id);
    });
    if (!mounted) return;
    await mostrarResultadoSessao(
      context,
      acertos: _acertos,
      erros: _erros,
      onEstudarNovamente: _resetar,
      onVoltar: () => context.go(widget.voltarPara),
    );
  }

  void _virarCard() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
      // conta como 1 card estudado só na primeira vez nesta sessão
      if (_cardsContados.add(_deck!.cards[_currentIndex].id)) {
        ProgressService.registrarCardEstudado();
      }
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  void _proximo() {
    if (_deck == null || _currentIndex >= _deck!.cards.length - 1) return;
    setState(() {
      _currentIndex++;
      _isFlipped = false;
    });
    _flipController.reset();
  }

  void _anterior() {
    if (_currentIndex <= 0) return;
    setState(() {
      _currentIndex--;
      _isFlipped = false;
    });
    _flipController.reset();
  }

  // "Estudar novamente" / botão recomeçar: zera tudo e abre sessão nova.
  void _resetar() {
    _timer?.cancel();
    setState(() {
      _currentIndex = 0;
      _isFlipped = false;
      _acertos = 0;
      _erros = 0;
      _encerrada = false;
    });
    _cardsContados.clear();
    _flipController.reset();
    if (widget.modo != null) {
      // recarrega o deck pra embaralhar de novo e reiniciar o cronômetro
      _carregarDeck();
    } else {
      _iniciarSessao(); // nova sessão de estudo do zero
    }
  }

  Future<void> _criarFlashcard() async {
    final p = _perguntaController.text.trim();
    final r = _respostaController.text.trim();
    if (p.isEmpty || r.isEmpty) {
      // RF02: pergunta e resposta são obrigatórias
      _mostrarErro('Preencha a pergunta e a resposta.');
      return;
    }

    try {
      final novo = await ApiService.criarFlashcard(
        pergunta: p,
        resposta: r,
        deckId: widget.deckId,
      );
      if (!mounted) return;
      setState(() {
        _deck = Deck(
          id: _deck!.id,
          nome: _deck!.nome,
          userId: _deck!.userId,
          cards: [..._deck!.cards, novo],
        );
        _perguntaController.clear();
        _respostaController.clear();
      });
      if (_deck!.cards.length == 1) _iniciarTimer(); // deck estava vazio
    } catch (e) {
      if (!mounted) return;
      _mostrarErro(e);
    }
  }

  // RF12 — foto (ou arquivo) → cards dentro deste deck.
  Future<void> _importarParaDeck() async {
    final resultado = await abrirImportacao(context, deckDestino: _deck);
    if (resultado == null || !mounted) return;
    final novos = resultado.cardsAdicionados;
    if (novos.isEmpty) return;
    setState(() {
      _deck = Deck(
        id: _deck!.id,
        nome: _deck!.nome,
        userId: _deck!.userId,
        cards: [..._deck!.cards, ...novos],
      );
    });
    if (_deck!.cards.length == novos.length) _iniciarTimer(); // estava vazio
    _mostrarErro(novos.length == 1
        ? '1 card adicionado'
        : '${novos.length} cards adicionados');
  }

  // Bloco 7 — busca um card do deck e pula direto pra ele (desvirado).
  Future<void> _buscarCard() async {
    final posicao = await mostrarBuscaCards(context, _deck!.cards);
    if (posicao == null || !mounted) return;
    setState(() {
      _currentIndex = posicao;
      _isFlipped = false;
    });
    _flipController.reset();
  }

  // RF06 — edita o card atual; mantém a posição e o lado virado do card.
  Future<void> _editarFlashcard() async {
    final atual = _deck!.cards[_currentIndex];
    final atualizado = await mostrarEditarFlashcard(context, atual);
    if (atualizado == null || !mounted) return;

    setState(() {
      _deck = Deck(
        id: _deck!.id,
        nome: _deck!.nome,
        userId: _deck!.userId,
        cards: _deck!.cards
            .map((c) => c.id == atualizado.id ? atualizado : c)
            .toList(),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Flashcard atualizado')),
    );
  }

  // RF05 — exclui o card atual (com confirmação).
  Future<void> _deletarFlashcard(int id) async {
    final confirmado = await confirmarExclusao(
      context,
      titulo: 'Excluir flashcard?',
      mensagem: 'Este flashcard será apagado permanentemente.',
    );
    if (!confirmado) return;

    try {
      await ApiService.deletarFlashcard(id);
      if (!mounted) return;
      setState(() {
        final novaLista = _deck!.cards.where((c) => c.id != id).toList();
        _deck = Deck(
            id: _deck!.id,
            nome: _deck!.nome,
            userId: _deck!.userId,
            cards: novaLista);
        _currentIndex = 0;
        _isFlipped = false;
      });
      _flipController.reset();
      if (_deck!.cards.isEmpty) _timer?.cancel(); // nada mais pra estudar
    } catch (e) {
      if (!mounted) return;
      _mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorRetry(message: _error!, onRetry: _carregarDeck)
                : Column(
                    children: [
                      _cabecalho(),
                      if (_deck!.cards.isNotEmpty) _barraProgresso(),
                      _formNovoCard(),
                      Expanded(
                        child: _deck!.cards.isEmpty
                            ? const Center(
                                child: Text('Nenhum card ainda.\nCrie o primeiro acima.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.textoSuave,
                                        fontSize: 15)))
                            // SingleChildScrollView: em telas/alturas
                            // menores (ex: teclado aberto) o card + botões
                            // podem não caber na área disponível.
                            : SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 8),
                                child: Column(
                                  children: [
                                    _cardComFlip(),
                                    const SizedBox(height: 16),
                                    _autoavaliacao(),
                                    const SizedBox(height: 8),
                                    // Wrap: se não couber lado a lado (letra
                                    // grande), o segundo botão desce de linha
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      children: [
                                        TextButton.icon(
                                          onPressed: _editarFlashcard,
                                          style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.textoSuave),
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18),
                                          label: const Text('Editar card'),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () => _deletarFlashcard(
                                              _deck!.cards[_currentIndex].id),
                                          style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.textoSuave),
                                          icon: const Icon(Icons.delete_outline,
                                              size: 18),
                                          label: const Text('Deletar card'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      if (_deck!.cards.isNotEmpty) _navegacao(),
                    ],
                  ),
      ),
    );
  }

  Widget _cabecalho() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(widget.voltarPara),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_deck?.nome ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                if (widget.modo != null)
                  Text(widget.modo!.titulo,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textoSuave)),
              ],
            ),
          ),
          // cronômetro do modo (fica vermelho cheio nos últimos 30s)
          if (widget.modo != null && _deck!.cards.isNotEmpty)
            ValueListenableBuilder<Duration>(
              valueListenable: _restante,
              builder: (context, restante, _) {
                final urgente = restante.inSeconds <= 30;
                return Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color:
                        urgente ? AppColors.vermelho : AppColors.vermelhoClaro,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 16,
                          color: urgente
                              ? Colors.white
                              : AppColors.vermelhoEscuro),
                      const SizedBox(width: 4),
                      Text(_formatarTempo(restante),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: urgente
                                  ? Colors.white
                                  : AppColors.vermelhoEscuro)),
                    ],
                  ),
                );
              },
            ),
          if (_deck!.cards.isNotEmpty)
            IconButton(
              tooltip: 'Buscar card',
              icon: const Icon(Icons.search),
              onPressed: _buscarCard,
            ),
          IconButton(
            tooltip: 'Recomeçar',
            icon: const Icon(Icons.refresh),
            onPressed: _resetar,
          ),
        ],
      ),
    );
  }

  Widget _barraProgresso() {
    final total = _deck!.cards.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text('Card ${_currentIndex + 1} de $total',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textoSuave)),
              const Spacer(),
              _Placar(
                  icone: Icons.check,
                  valor: _acertos,
                  cor: AppColors.verde,
                  fundo: AppColors.verdeClaro,
                  rotulo: 'acertos'),
              const SizedBox(width: 6),
              _Placar(
                  icone: Icons.close,
                  valor: _erros,
                  cor: AppColors.vermelhoEscuro,
                  fundo: AppColors.vermelhoClaro,
                  rotulo: 'erros'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / total,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // Formulário de criar card: as duas caixas lado a lado, com rótulo em
  // cima, pra ocupar pouca altura e deixar o card em destaque.
  Widget _formNovoCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppCampo(
                  controller: _perguntaController,
                  rotulo: 'Pergunta',
                  dica: 'Ex.: き',
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppCampo(
                  controller: _respostaController,
                  rotulo: 'Resposta',
                  dica: 'Ex.: ki',
                  onSubmitted: (_) => _criarFlashcard(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _criarFlashcard,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.vermelhoClaro,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Criar flashcard'),
                ),
              ),
              const SizedBox(width: 8),
              // RF12: foto (câmera/galeria) ou arquivo → cards neste deck
              OutlinedButton.icon(
                onPressed: _importarParaDeck,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Da foto'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardComFlip() {
    final card = _deck!.cards[_currentIndex];
    return GestureDetector(
      onTap: _virarCard,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          // Rotação 3D no eixo Y (igual ao CSS rotateY)
          final angle = _flipAnimation.value * pi;
          final showBack = angle > pi / 2;
          final texto = showBack ? card.resposta : card.pergunta;
          // um kana/kanji sozinho fica grande; frases ficam menores
          final tamanho = texto.characters.length <= 3 ? 64.0 : 24.0;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: Transform(
              // corrige o texto que ficaria espelhado
              transform:
                  showBack ? (Matrix4.identity()..rotateY(pi)) : Matrix4.identity(),
              alignment: Alignment.center,
              child: Container(
                width: double.infinity,
                height: 240,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.superficie,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: showBack ? const Color(0xFFF0C3C8) : AppColors.linha,
                    width: showBack ? 1.5 : 1,
                  ),
                  boxShadow: sombraSuave,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(showBack ? 'RESPOSTA' : 'PERGUNTA',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: showBack
                                    ? AppColors.vermelhoEscuro
                                    : AppColors.textoSuave)),
                        const Spacer(),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: AppColors.vermelho,
                              shape: BoxShape.circle),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          texto,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: tamanho,
                            fontWeight: tamanho > 30
                                ? FontWeight.w400
                                : FontWeight.w700,
                            color: showBack
                                ? AppColors.vermelho
                                : AppColors.texto,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      showBack
                          ? 'Toque para ver a pergunta'
                          : 'Toque para ver a resposta',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textoSuave),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Antes de virar: dica. Depois de virar: Errei / Acertei grandes.
  Widget _autoavaliacao() {
    if (!_isFlipped) {
      return const SizedBox(
        height: 56,
        child: Center(
          child: Text('Toque para virar',
              style: TextStyle(color: AppColors.textoSuave, fontSize: 13)),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _responder(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.vermelhoEscuro,
              minimumSize: const Size(0, 56),
              side: const BorderSide(color: Color(0xFFF0C3C8), width: 1.5),
            ),
            icon: const Icon(Icons.close),
            label: const Text('Errei'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _responder(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.verde,
              minimumSize: const Size(0, 56),
            ),
            icon: const Icon(Icons.check),
            label: const Text('Acertei'),
          ),
        ),
      ],
    );
  }

  Widget _navegacao() {
    final ultimo = _currentIndex == _deck!.cards.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _currentIndex > 0 ? _anterior : null,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Anterior'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            // .icon com o ícone no fim: o Flutter encolhe o texto se faltar
            // espaço (letra grande), em vez de estourar o botão
            child: OutlinedButton.icon(
              onPressed: ultimo ? null : _proximo,
              iconAlignment: IconAlignment.end,
              icon: Icon(ultimo ? Icons.check : Icons.arrow_forward, size: 18),
              label: Text(ultimo ? 'Concluído' : 'Próximo'),
            ),
          ),
        ],
      ),
    );
  }
}

// Contador pequeno de acertos/erros no topo da tela de estudo
class _Placar extends StatelessWidget {
  final IconData icone;
  final int valor;
  final Color cor;
  final Color fundo;
  final String rotulo;

  const _Placar({
    required this.icone,
    required this.valor,
    required this.cor,
    required this.fundo,
    required this.rotulo,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$valor $rotulo',
      excludeSemantics: true,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
            color: fundo, borderRadius: BorderRadius.circular(999)),
        child: Row(
          children: [
            Icon(icone, size: 14, color: cor),
            const SizedBox(width: 3),
            Text('$valor',
                style: TextStyle(
                    color: cor, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
