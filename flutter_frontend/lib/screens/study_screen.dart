import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/deck.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
import '../widgets/app_drawer.dart';

class StudyScreen extends StatefulWidget {
  final int deckId;
  const StudyScreen({super.key, required this.deckId});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  Deck? _deck;
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _loading = true;

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
    _flipController.dispose();
    _perguntaController.dispose();
    _respostaController.dispose();
    super.dispose();
  }

  Future<void> _carregarDeck() async {
    final deck = await ApiService.buscarDeck(widget.deckId);
    setState(() {
      _deck = deck;
      _loading = false;
    });
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
    setState(() {
      _currentIndex = 0;
      _isFlipped = false;
    });
    _flipController.reset();
  }

  Future<void> _criarFlashcard() async {
    final p = _perguntaController.text.trim();
    final r = _respostaController.text.trim();
    if (p.isEmpty || r.isEmpty) return;

    final novo = await ApiService.criarFlashcard(
      pergunta: p,
      resposta: r,
      deckId: widget.deckId,
    );
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
  }

  Future<void> _deletarFlashcard(int id) async {
    await ApiService.deletarFlashcard(id);
    setState(() {
      final novaLista =
          _deck!.cards.where((c) => c.id != id).toList();
      _deck = Deck(
          id: _deck!.id,
          nome: _deck!.nome,
          userId: _deck!.userId,
          cards: novaLista);
      _currentIndex = 0;
      _isFlipped = false;
    });
    _flipController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDC2626), Color(0xFF991B1B), Colors.black],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
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
                            child: Text(
                              _deck?.nome ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
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
                                Text(
                                  '${_currentIndex + 1} / ${_deck!.cards.length}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
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
                                            height: 180,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            decoration: BoxDecoration(
                                              color: showBack
                                                  ? Colors.white
                                              // ignore: deprecated_member_use
                                                  : Colors.white.withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(20),
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
                                  const Text('Toque para virar',
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 12)),
                                  const SizedBox(height: 12),
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
