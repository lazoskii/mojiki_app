import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/error_retry.dart';
import '../widgets/rename_deck_dialog.dart';
import '../theme/app_theme.dart';
import '../utils/busca.dart';
import '../widgets/campo_busca.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // equivale aos useState do React:
  List<Deck> _decks = [];
  bool _loading = true;
  String? _error;
  String _userName = 'Estudante';
  final _novoDeckController = TextEditingController();

  // Bloco 7 — busca de decks pelo nome (filtra a lista já carregada)
  final _buscaController = TextEditingController();
  String _busca = '';

  List<Deck> get _decksFiltrados =>
      _decks.where((d) => combinaBusca(_busca, [d.nome])).toList();

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _novoDeckController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  // equivale ao useEffect(() => fetch(...), [])
  Future<void> _carregarDados() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final decks = await ApiService.listarDecks();
      if (!mounted) return;
      setState(() {
        _userName = prefs.getString('userName') ?? 'Estudante';
        _decks = decks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _mostrarErro(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }

  Future<void> _criarDeck() async {
    final nome = _novoDeckController.text.trim();
    if (nome.isEmpty) {
      // RF01: nome vazio ou só espaços não cria deck
      _mostrarErro('Digite um nome para o deck.');
      return;
    }

    try {
      final novo = await ApiService.criarDeck(nome);
      if (!mounted) return;
      setState(() {
        _decks.add(novo);
        _novoDeckController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      _mostrarErro(e);
    }
  }

  // RF07 — renomear deck; troca só o deck editado na lista.
  Future<void> _renomearDeck(Deck deck) async {
    final atualizado = await mostrarRenomearDeck(context, deck);
    if (atualizado == null || !mounted) return;

    setState(() {
      // o PUT não devolve a contagem de cards, então mantém a que já tinha
      _decks = _decks
          .map((d) => d.id == atualizado.id
              ? Deck(
                  id: d.id,
                  nome: atualizado.nome,
                  userId: d.userId,
                  totalCards: d.totalCards)
              : d)
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deck renomeado')),
    );
  }

  Future<void> _deletarDeck(int id, String nome) async {
    final confirmado = await confirmarExclusao(
      context,
      titulo: 'Excluir deck?',
      mensagem:
          'O deck "$nome" e todos os seus flashcards serão apagados permanentemente.',
    );
    if (!confirmado) return;

    try {
      await ApiService.deletarDeck(id);
      if (!mounted) return;
      setState(() => _decks.removeWhere((d) => d.id == id));
    } catch (e) {
      if (!mounted) return;
      _mostrarErro(e);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isAuthenticated');
    await prefs.remove('userName');
    if (!mounted) return;
    context.go('/welcome');
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
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _error != null
                  ? ErrorRetry(message: _error!, onRetry: _carregarDados)
                  : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white70),
                            onPressed: _logout,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        'Olá, $_userName!',
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _decks.isEmpty
                            ? 'Crie seu primeiro deck para começar'
                            : '${_decks.length} decks · '
                                '${_decks.fold<int>(0, (s, d) => s + d.totalCards)} cards',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input para criar deck
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _novoDeckController,
                              style: const TextStyle(color: Colors.white),
                              onSubmitted: (_) => _criarDeck(),
                              decoration: InputDecoration(
                                hintText: 'Nome do novo deck',
                                prefixIcon: const Icon(Icons.create_new_folder_outlined,
                                    color: Colors.white54, size: 20),
                                fillColor: Colors.white.withValues(alpha: 0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _criarDeck,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Criar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.vermelho,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Busca de decks (Bloco 7) — só aparece quando há decks
                    if (_decks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: CampoBusca(
                          controller: _buscaController,
                          dica: 'Buscar deck pelo nome',
                          onChanged: (texto) => setState(() => _busca = texto),
                        ),
                      )
                    else
                      const SizedBox(height: 4),

                    // Grid de decks — equivale ao grid-cols-2 do Tailwind
                    Expanded(
                      child: _decks.isNotEmpty && _decksFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off,
                                      color: Colors.white38, size: 44),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Nenhum deck encontrado para "$_busca"',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 15),
                                  ),
                                ],
                              ),
                            )
                          : _decks.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.style_outlined,
                                      color: Colors.white38, size: 48),
                                  SizedBox(height: 12),
                                  Text(
                                    'Nenhum deck ainda.\nCrie seu primeiro deck!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white60, fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, // 2 colunas
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.1,
                              ),
                              itemCount: _decksFiltrados.length,
                              itemBuilder: (context, index) {
                                final deck = _decksFiltrados[index];
                                return _DeckCard(
                                  deck: deck,
                                  onTap: () =>
                                      context.go('/study/${deck.id}'),
                                  onEdit: () => _renomearDeck(deck),
                                  onDelete: () =>
                                      _deletarDeck(deck.id, deck.nome),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// Widget de card de deck — equivale ao componente DeckCard.tsx
class _DeckCard extends StatelessWidget {
  final Deck deck;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeckCard({
    required this.deck,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Material + InkWell = efeito de toque (ripple) no card inteiro
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.style, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  deck.nome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  // Expanded + ellipsis: com letra grande (acessibilidade)
                  // a contagem encolhe em vez de estourar o card
                  Expanded(
                    child: Text(
                      deck.totalCards == 1 ? '1 card' : '${deck.totalCards} cards',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                  _AcaoDeck(icone: Icons.edit_outlined, onTap: onEdit),
                  const SizedBox(width: 6),
                  _AcaoDeck(
                    icone: Icons.delete_outline,
                    onTap: onDelete,
                    cor: Colors.red.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Botãozinho quadrado de editar/excluir no canto do card de deck
class _AcaoDeck extends StatelessWidget {
  final IconData icone;
  final VoidCallback onTap;
  final Color? cor;

  const _AcaoDeck({required this.icone, required this.onTap, this.cor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cor ?? Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icone, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}
