import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/error_retry.dart';
import '../widgets/rename_deck_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _novoDeckController.dispose();
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
    if (nome.isEmpty) return;

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
      _decks = _decks.map((d) => d.id == atualizado.id ? atualizado : d).toList();
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDC2626), Color(0xFF991B1B), Colors.black],
          ),
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
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Escolha um deck para estudar',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
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
                              decoration: InputDecoration(
                                hintText: 'Nome do deck',
                                hintStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _criarDeck,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Criar'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid de decks — equivale ao grid-cols-2 do Tailwind
                    Expanded(
                      child: _decks.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum deck ainda.\nCrie seu primeiro deck!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 16),
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
                              itemCount: _decks.length,
                              itemBuilder: (context, index) {
                                final deck = _decks[index];
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              deck.nome,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
