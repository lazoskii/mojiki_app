import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'app_campo.dart';

// Painel "Novo deck" (botão "+ Novo deck" da Home). Antes o campo de criar
// deck ficava sempre aberto no topo da Home. Cria via POST /decks e
// devolve o deck novo, ou null se fechar sem criar.
Future<Deck?> mostrarNovoDeck(BuildContext context) {
  return showModalBottomSheet<Deck>(
    context: context,
    isScrollControlled: true, // sobe junto com o teclado
    builder: (_) => const _NovoDeckSheet(),
  );
}

class _NovoDeckSheet extends StatefulWidget {
  const _NovoDeckSheet();

  @override
  State<_NovoDeckSheet> createState() => _NovoDeckSheetState();
}

class _NovoDeckSheetState extends State<_NovoDeckSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _salvando = false;
  String? _erroApi;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    setState(() => _erroApi = null);
    if (!_formKey.currentState!.validate()) return; // RF01
    setState(() => _salvando = true);
    try {
      final deck = await ApiService.criarDeck(_controller.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(deck);
    } catch (e) {
      if (!mounted) return;
      // ex.: "O campo Nome do deck não pode ficar vazio" vindo do backend
      setState(() {
        _salvando = false;
        _erroApi = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Novo deck',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Agrupe cards de um mesmo assunto',
                style: TextStyle(color: AppColors.textoSuave)),
            const SizedBox(height: 20),
            AppCampo(
              controller: _controller,
              rotulo: 'Nome do deck',
              dica: 'Ex.: Hiragana básico',
              autofocus: true,
              erroExterno: _erroApi,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _criar(),
              validator: (texto) => texto.trim().isEmpty
                  ? 'Digite um nome para o deck.'
                  : null,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _salvando ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _salvando ? null : _criar,
                    child: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Criar deck'),
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
