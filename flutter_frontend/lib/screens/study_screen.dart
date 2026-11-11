import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/deck.dart';
import '../models/modo_estudo.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/buscar_card_sheet.dart';
import '../widgets/edit_flashcard_dialog.dart';
import '../widgets/error_retry.dart';
import '../widgets/session_results_dialog.dart';
import '../theme/app_theme.dart';

class StudyScreen extends StatefulWidget {
  final int deckId;
  final ModoEstudo? modo; // null = deck aberto direto da Home (estudo livre)
  const StudyScreen({super.key, required this.deckId, this.modo});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  Deck? _deck;
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _loading = true;
  String? _error;

  // autoavaliação (Acertei / Errei)
  int? _sessaoId;
  int _acertos = 0;
  int _erros = 0;
  bool _respondendo = false; // evita duplo toque enquanto a API responde

  // modos de estudo (Bloco 6): cronômetro da sessão
  Timer? _timer;
  Duration _restante = Duration.zero;
  bool _encerrada = false; // evita finalizar duas vezes (último card + tempo)

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
      duration: const Duration(milliseconds: 400),
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
    _flipController.dispose();
    _perguntaController.dispose();
    _respostaController.dispose();
    super.dispose();
  }

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
      _iniciarTimer();
      await _iniciarSessao();
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

    setState(() => _restante = modo.duracao);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _restante -= const Duration(seconds: 1));
      if (_restante <= Duration.zero) {
        timer.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tempo esgotado!')),
        );
        _finalizarSessao();
      }
    });
  }

  String get _tempoFormatado {
    final min = _restante.inMinutes.toString().padLeft(2, '0');
    final seg = (_restante.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$seg';
  }

  void _mostrarErro(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }

  Future<void> _iniciarSessao() async {
    try {
      final sessao = await ApiService.iniciarSessao(
        userId: usuarioFixoId, // pendência: ver api_service.dart
        deckId: widget.deckId,
        modo: widget.modo?.name,
      );
      if (!mounted) return;
      setState(() => _sessaoId = sessao['id']);
    } catch (e) {
      debugPrint('Falha ao iniciar sessão de estudo: $e');
      if (!mounted) return;
      _mostrarErro(e);
    }
  }

  // Registra a autoavaliação (Acertei/Errei) do card atual na sessão em
  // andamento e avança para o próximo card (ou finaliza a sessão).
  Future<void> _responder(bool acerto) async {
    if (_sessaoId == null || _respondendo || _encerrada) return;

    setState(() => _respondendo = true);
    try {
      await ApiService.registrarResposta(
        sessaoId: _sessaoId!,
        acerto: acerto,
      );
      if (!mounted) return;
      setState(() {
        if (acerto) {
          _acertos++;
        } else {
          _erros++;
        }
      });
      if (acerto) await ProgressService.registrarAcerto();

      // Sessão Intensiva: card errado volta pro fim da fila
      if (!acerto && (widget.modo?.repeteErros ?? false) && mounted) {
        setState(() {
          _deck = Deck(
            id: _deck!.id,
            nome: _deck!.nome,
            userId: _deck!.userId,
            cards: [..._deck!.cards, _deck!.cards[_currentIndex]],
          );
        });
      }
    } catch (e) {
      debugPrint('Falha ao registrar resposta: $e');
      if (mounted) _mostrarErro(e);
    }

    if (!mounted || _encerrada) return; // o tempo pode ter acabado no meio
    setState(() => _respondendo = false);

    final ultimoCard = _currentIndex >= _deck!.cards.length - 1;
    if (ultimoCard) {
      await _finalizarSessao();
    } else {
      _proximo();
    }
  }

  Future<void> _finalizarSessao() async {
    if (_encerrada) return;
    _encerrada = true;
    _timer?.cancel();

    if (_sessaoId != null) {
      try {
        await ApiService.finalizarSessao(_sessaoId!);
      } catch (e) {
        debugPrint('Falha ao finalizar sessão: $e');
        if (mounted) _mostrarErro(e);
      }
    }
    if (!mounted) return;
    await mostrarResultadoSessao(
      context,
      acertos: _acertos,
      erros: _erros,
      onEstudarNovamente: _resetar,
      onVoltar: () => context.go('/home'),
    );
  }

  void _virarCard() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
      ProgressService.registrarCardEstudado(); // conta como 1 revisão
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

  void _resetar() {
    _timer?.cancel();
    setState(() {
      _currentIndex = 0;
      _isFlipped = false;
      _acertos = 0;
      _erros = 0;
      _sessaoId = null;
      _encerrada = false;
      _respondendo = false;
    });
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
    } catch (e) {
      if (!mounted) return;
      _mostrarErro(e);
    }
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
    } catch (e) {
      if (!mounted) return;
      _mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.fundo,
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : _error != null
                  ? ErrorRetry(message: _error!, onRetry: _carregarDeck)
                  : Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => context.go('/home'),
                          ),
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white70),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  _deck?.nome ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600),
                                ),
                                if (widget.modo != null)
                                  Text(
                                    widget.modo!.titulo,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          // cronômetro do modo (fica vermelho nos últimos 30s)
                          if (widget.modo != null && _deck!.cards.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _restante.inSeconds <= 30
                                    ? Colors.red.withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer_outlined,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(_tempoFormatado,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          if (_deck!.cards.isNotEmpty)
                            IconButton(
                              tooltip: 'Buscar card',
                              icon: const Icon(Icons.search, color: Colors.white),
                              onPressed: _buscarCard,
                            ),
                          IconButton(
                            tooltip: 'Recomeçar',
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            onPressed: _resetar,
                          ),
                        ],
                      ),
                    ),

                    // Barra de progresso
                    if (_deck!.cards.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Progresso',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: const Color(0xFF16A34A),
                                        size: 14),
                                    const SizedBox(width: 2),
                                    Text('$_acertos',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.cancel,
                                        color: Colors.red, size: 14),
                                    const SizedBox(width: 2),
                                    Text('$_erros',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${_currentIndex + 1} / ${_deck!.cards.length}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                // equivale ao motion.div de width animada
                                value: (_currentIndex + 1) /
                                    _deck!.cards.length,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Formulário para criar flashcard
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          _buildInput(_perguntaController, 'Pergunta'),
                          const SizedBox(height: 8),
                          _buildInput(_respostaController, 'Resposta'),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _criarFlashcard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFDC2626),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('+ Criar Flashcard'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Área do flashcard
                    Expanded(
                      child: _deck!.cards.isEmpty
                          ? const Center(
                              child: Text('Nenhum card ainda',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 16)))
                          : Center(
                              // SingleChildScrollView: em telas/alturas
                              // menores (ex: teclado aberto) o card + botões
                              // + "Deletar card" podem não caber na área
                              // disponível. Sem isso, essa Column dava
                              // overflow de RenderFlex (bug encontrado ao
                              // rodar os testes de widget).
                              child: SingleChildScrollView(
                                child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Card com animação de flip
                                  GestureDetector(
                                    onTap: _virarCard,
                                    child: AnimatedBuilder(
                                      animation: _flipAnimation,
                                      builder: (context, child) {
                                        // Rotação 3D no eixo Y (igual ao CSS rotateY)
                                        final angle =
                                            _flipAnimation.value * pi;
                                        final showBack = angle > pi / 2;
                                        return Transform(
                                          transform: Matrix4.identity()
                                            ..setEntry(3, 2, 0.001)
                                            ..rotateY(angle),
                                          alignment: Alignment.center,
                                          child: Container(
                                            width: double.infinity,
                                            height: 210,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: showBack
                                                  ? Colors.white
                                                  : Colors.white.withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              border: Border.all(
                                                  color: Colors.white.withValues(
                                                      alpha: showBack ? 0 : 0.25)),
                                              boxShadow: const [
                                                BoxShadow(
                                                    color: Colors.black38,
                                                    blurRadius: 16,
                                                    offset: Offset(0, 6)),
                                              ],
                                            ),
                                            child: Center(
                                              child: Transform(
                                                // corrige o texto que ficaria espelhado
                                                transform: showBack
                                                    ? (Matrix4.identity()
                                                      ..rotateY(pi))
                                                    : Matrix4.identity(),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  showBack
                                                      ? _deck!.cards[_currentIndex].resposta
                                                      : _deck!.cards[_currentIndex].pergunta,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: showBack
                                                        ? const Color(0xFFDC2626)
                                                        : Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (!_isFlipped)
                                    const Text('Toque para virar',
                                        style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12))
                                  else
                                    Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: _respondendo
                                                  ? null
                                                  : () => _responder(false),
                                              icon: const Icon(Icons.close,
                                                  color: Colors.red),
                                              label: const Text('Errei',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets
                                                    .symmetric(vertical: 12),
                                                side: const BorderSide(
                                                    color: Colors.red),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: _respondendo
                                                  ? null
                                                  : () => _responder(true),
                                              icon: const Icon(Icons.check,
                                                  color: Colors.white),
                                              label: const Text('Acertei'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF16A34A),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets
                                                    .symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  // Wrap: se não couber lado a lado (letra
                                  // grande), o segundo botão desce de linha
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    children: [
                                      TextButton.icon(
                                        onPressed: _editarFlashcard,
                                        icon: const Icon(Icons.edit_outlined,
                                            color: Colors.white70, size: 18),
                                        label: const Text('Editar card',
                                            style: TextStyle(
                                                color: Colors.white70)),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => _deletarFlashcard(
                                            _deck!.cards[_currentIndex].id),
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red, size: 18),
                                        label: const Text('Deletar card',
                                            style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                ],
                                ),
                              ),
                            ),
                    ),

                    // Botões de navegação
                    if (_deck!.cards.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _currentIndex > 0 ? _anterior : null,
                                icon: const Icon(Icons.arrow_back,
                                    color: Colors.white),
                                label: const Text('Anterior',
                                    style: TextStyle(color: Colors.white)),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.3)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _currentIndex <
                                        _deck!.cards.length - 1
                                    ? _proximo
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFDC2626),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  _currentIndex == _deck!.cards.length - 1
                                      ? 'Concluído'
                                      : 'Próximo',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}
