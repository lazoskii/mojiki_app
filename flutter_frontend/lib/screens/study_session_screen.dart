import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck.dart';
import '../models/modo_estudo.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_retry.dart';
import '../widgets/menu_perfil.dart';

// Aba "Estudar": escolha de modo de estudo + acesso rápido aos decks
// (equivale a StudySession.tsx do frontend React).
class StudySessionScreen extends StatefulWidget {
  const StudySessionScreen({super.key});

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  List<Deck> _decks = [];
  bool _loading = true;
  String? _error;
  String _userName = 'Estudante';

  @override
  void initState() {
    super.initState();
    _carregarDecks();
  }

  Future<void> _carregarDecks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // GET /decks já devolve total_cards; antes era preciso buscar o
      // detalhe de cada deck só pra contar os cards.
      final decks = await ApiService.listarDecks();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _decks = decks;
        _userName = prefs.getString('userName') ?? 'Estudante';
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

  // RF08 — tocar num modo abre a lista de decks; escolher um deck abre a
  // tela de estudo com as regras do modo (/study/{id}?modo=...).
  Future<void> _escolherDeck(ModoEstudo modo) async {
    final comCards = _decks.where((d) => d.totalCards > 0).toList();
    if (comCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crie um deck com cards antes de estudar.')),
      );
      return;
    }

    final deck = await showModalBottomSheet<Deck>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    _IconeModo(modo: modo, tamanho: 40),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(modo.titulo,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const Text('Escolha o deck',
                            style: TextStyle(color: AppColors.textoSuave)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              for (final d in comCards)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(d.nome,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                      d.totalCards == 1 ? '1 card' : '${d.totalCards} cards'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(sheetContext).pop(d),
                ),
            ],
          ),
        ),
      ),
    );
    if (deck == null || !mounted) return;
    context.go('/study/${deck.id}?modo=${modo.name}&voltar=/study-session');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorRetry(message: _error!, onRetry: _carregarDecks)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Estudar',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700)),
                                Text('Escolha um modo e depois o deck',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textoSuave)),
                              ],
                            ),
                          ),
                          BotaoPerfil(nome: _userName),
                        ],
                      ),
                      const SizedBox(height: 20),
                      for (final modo in ModoEstudo.values) ...[
                        _CardModo(modo: modo, onTap: () => _escolherDeck(modo)),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 12),
                      const Text('Ou estude um deck livremente',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Sem cronômetro, na ordem dos cards',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textoSuave)),
                      const SizedBox(height: 12),
                      if (_decks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Nenhum deck ainda.\nCrie um na aba Decks!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textoSuave),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 84,
                          ),
                          itemCount: _decks.length,
                          itemBuilder: (context, index) {
                            final deck = _decks[index];
                            return Material(
                              color: AppColors.superficie,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: AppColors.linha),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () =>
                                    context.go('/study/${deck.id}?voltar=/study-session'),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(deck.nome,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(
                                          deck.totalCards == 1
                                              ? '1 card'
                                              : '${deck.totalCards} cards',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textoSuave)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _IconeModo extends StatelessWidget {
  final ModoEstudo modo;
  final double tamanho;

  const _IconeModo({required this.modo, this.tamanho = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: modo.corClara,
        borderRadius: BorderRadius.circular(tamanho * 0.27),
      ),
      child: Icon(modo.icone, color: modo.cor, size: tamanho * 0.5),
    );
  }
}

class _CardModo extends StatelessWidget {
  final ModoEstudo modo;
  final VoidCallback onTap;

  const _CardModo({required this.modo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.linha),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _IconeModo(modo: modo),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(modo.titulo,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(modo.descricao,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textoSuave)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.fundo,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${modo.duracao.inMinutes} min',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textoFraco),
            ],
          ),
        ),
      ),
    );
  }
}
