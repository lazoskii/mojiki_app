import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import '../utils/busca.dart';
import '../widgets/campo_busca.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/error_retry.dart';
import '../widgets/importar.dart';
import '../widgets/menu_perfil.dart';
import '../widgets/novo_deck_sheet.dart';
import '../widgets/rename_deck_dialog.dart';

// Home (aba "Decks"). Organizada de cima pra baixo por prioridade:
// saudação → sequência/nível → atalho "Continuar estudando" → busca →
// lista de decks com "+ Novo deck".
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
  int _streak = 0;
  int _nivel = 1;
  int _xp = 0;
  int? _ultimoDeckId;

  // Bloco 7 — busca de decks pelo nome (filtra a lista já carregada)
  final _buscaController = TextEditingController();
  String _busca = '';

  List<Deck> get _decksFiltrados =>
      _decks.where((d) => combinaBusca(_busca, [d.nome])).toList();

  // Deck do atalho: o último aberto (se ainda tem cards), senão o
  // primeiro com cards. Null = não há nada pra estudar ainda.
  Deck? get _deckContinuar {
    final comCards = _decks.where((d) => d.totalCards > 0);
    for (final d in comCards) {
      if (d.id == _ultimoDeckId) return d;
    }
    return comCards.isEmpty ? null : comCards.first;
  }

  int get _totalCards => _decks.fold<int>(0, (s, d) => s + d.totalCards);

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
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
      final stats = await ProgressService.obterStats();
      final ultimo = await ProgressService.ultimoDeck();
      if (!mounted) return;
      setState(() {
        _userName = prefs.getString('userName') ?? 'Estudante';
        _decks = decks;
        _streak = stats.streak;
        _nivel = stats.nivel;
        _xp = stats.xp;
        _ultimoDeckId = ultimo;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  // RF01 (nome obrigatório) agora é validado dentro do painel "Novo deck".
  Future<void> _criarDeck() async {
    final novo = await mostrarNovoDeck(context);
    if (novo == null || !mounted) return;
    setState(() => _decks.add(novo));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deck "${novo.nome}" criado')));
  }

  // RF11/RF12 — importa um deck de arquivo ou foto (com revisão antes).
  Future<void> _importarDeck() async {
    final resultado = await abrirImportacao(context);
    final deck = resultado?.deckNovo;
    if (deck == null || !mounted) return;
    setState(() => _decks.add(deck));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deck "${deck.nome}" importado com ${deck.totalCards} cards',
        ),
      ),
    );
  }

  // RF07 — renomear deck; troca só o deck editado na lista.
  Future<void> _renomearDeck(Deck deck) async {
    final atualizado = await mostrarRenomearDeck(context, deck);
    if (atualizado == null || !mounted) return;

    setState(() {
      // o PUT não devolve a contagem de cards, então mantém a que já tinha
      _decks = _decks
          .map(
            (d) => d.id == atualizado.id
                ? Deck(
                    id: d.id,
                    nome: atualizado.nome,
                    userId: d.userId,
                    totalCards: d.totalCards,
                  )
                : d,
          )
          .toList();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Deck renomeado')));
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

  @override
  Widget build(BuildContext context) {
    // Scaffold próprio (dentro do AppShell): os avisos (SnackBar) aparecem
    // acima da barra de navegação.
    return Scaffold(body: _conteudo(context));
  }

  Widget _conteudo(BuildContext context) {
    if (_loading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return SafeArea(
        child: ErrorRetry(message: _error!, onRetry: _carregarDados),
      );
    }

    final filtrados = _decksFiltrados;
    final continuar = _deckContinuar;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _carregarDados,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            // Saudação + perfil
            Row(
              children: [
                const _Hinomaru(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, $_userName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _decks.isEmpty
                            ? 'Crie seu primeiro deck para começar'
                            : '${_decks.length} decks · $_totalCards cards',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
                BotaoPerfil(nome: _userName),
              ],
            ),
            const SizedBox(height: 16),

            // Sequência e nível
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  icone: Icons.local_fire_department,
                  cor: AppColors.laranja,
                  texto: _streak == 1
                      ? '1 dia seguido'
                      : '$_streak dias seguidos',
                ),
                _Chip(
                  icone: Icons.star_rounded,
                  cor: AppColors.amarelo,
                  texto:
                      'Nível $_nivel · ${_xp % ProgressService.xpPorNivel}/${ProgressService.xpPorNivel} XP',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Atalho: um toque já começa uma Prática Diária
            // (some durante a busca, pra tela mostrar só os resultados)
            if (continuar != null && _busca.trim().isEmpty) ...[
              _CardContinuar(
                deck: continuar,
                titulo: continuar.id == _ultimoDeckId
                    ? 'CONTINUAR ESTUDANDO'
                    : 'COMECE POR AQUI',
                onComecar: () =>
                    context.go('/study/${continuar.id}?modo=diaria'),
              ),
              const SizedBox(height: 16),
            ],

            // Busca de decks (Bloco 7) — só aparece quando há decks
            if (_decks.isNotEmpty) ...[
              CampoBusca(
                controller: _buscaController,
                dica: 'Buscar deck pelo nome',
                onChanged: (texto) => setState(() => _busca = texto),
              ),
              const SizedBox(height: 20),
            ],

            const Text('Seus decks',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            // Dois botões do mesmo tamanho: importar (secundário) e criar
            // (principal). Expanded = cada um ocupa metade; se faltar
            // espaço, o texto encolhe em vez de estourar a tela.
            Row(
              children: [
                Expanded(
                  // RF11/RF12: Anki, Excel, CSV, PDF ou foto → deck novo
                  child: OutlinedButton.icon(
                    onPressed: _importarDeck,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44)),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Importar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _criarDeck,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44)),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Novo deck'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_decks.isEmpty)
              const _Vazio(
                icone: Icons.style_outlined,
                texto:
                    'Nenhum deck ainda.\nToque em "Novo deck" para criar o primeiro.',
              )
            else if (filtrados.isEmpty)
              _Vazio(
                icone: Icons.search_off,
                texto: 'Nenhum deck encontrado para "$_busca"',
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 158,
                ),
                itemCount: filtrados.length,
                itemBuilder: (context, index) {
                  final deck = filtrados[index];
                  return _DeckCard(
                    deck: deck,
                    onTap: () => context.go('/study/${deck.id}'),
                    onEdit: () => _renomearDeck(deck),
                    onDelete: () => _deletarDeck(deck.id, deck.nome),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// Círculo vermelho com 文 — a "bandeira" da marca (hinomaru)
class _Hinomaru extends StatelessWidget {
  const _Hinomaru();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.vermelho,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        '文',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String texto;

  const _Chip({required this.icone, required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.linha),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 18, color: cor),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CardContinuar extends StatelessWidget {
  final Deck deck;
  final String titulo;
  final VoidCallback onComecar;

  const _CardContinuar({
    required this.deck,
    required this.titulo,
    required this.onComecar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.vermelho,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40D1283A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deck.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Prática Diária · 15 min · ${deck.totalCards == 1 ? '1 card' : '${deck.totalCards} cards'}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onComecar,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.vermelho,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Começar'),
          ),
        ],
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _Vazio({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icone, color: AppColors.textoFraco, size: 44),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textoSuave, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// Card de deck: inicial do nome, menu "⋯" (renomear/excluir) e "Estudar →".
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

  String get _inicial {
    final nome = deck.nome.trim();
    if (nome.isEmpty) return '?';
    return String.fromCharCode(nome.runes.first).toUpperCase();
  }

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
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.vermelhoClaro,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _inicial,
                      style: const TextStyle(
                        color: AppColors.vermelho,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Opções do deck',
                    icon: const Icon(
                      Icons.more_horiz,
                      color: AppColors.textoSuave,
                    ),
                    onSelected: (opcao) =>
                        opcao == 'renomear' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'renomear',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Renomear'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'excluir',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: AppColors.erro,
                          ),
                          title: Text(
                            'Excluir',
                            style: TextStyle(color: AppColors.erro),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    deck.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    // Expanded + ellipsis: com letra grande (acessibilidade)
                    // a contagem encolhe em vez de estourar o card
                    Expanded(
                      child: Text(
                        deck.totalCards == 1
                            ? '1 card'
                            : '${deck.totalCards} cards',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Text(
                      'Estudar →',
                      style: TextStyle(
                        color: AppColors.vermelho,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
}
