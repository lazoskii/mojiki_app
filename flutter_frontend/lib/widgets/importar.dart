import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../models/importacao.dart';
import '../screens/previa_importacao_screen.dart';
import '../services/api_service.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';

// Importação de decks (RF11) e foto → cards (RF12) — o "começo" do fluxo:
//   1. painel com as opções (arquivo / tirar foto / galeria);
//   2. escolhe o arquivo ou a imagem;
//   3. manda pro backend ler (com tela de "Lendo...");
//   4. abre a tela de prévia pra revisar; ela grava e devolve o resultado.

// O que a importação produziu: um deck novo OU cards num deck existente.
class ResultadoImportacao {
  final Deck? deckNovo;
  final List<Flashcard> cardsAdicionados;

  const ResultadoImportacao({this.deckNovo, this.cardsAdicionados = const []});
}

// Extensões aceitas pelo backend (ver backend/importador.py)
const _extensoesArquivo = ['apkg', 'colpkg', 'xlsx', 'csv', 'tsv', 'txt', 'pdf'];

// Câmera direta só faz sentido no celular e no navegador
// (no Windows o image_picker não tem câmera).
bool get _temCamera =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

// Abre o painel de opções. `deckDestino` != null = os cards entram nesse
// deck (usado na tela de estudo); null = cria um deck novo (Home).
Future<ResultadoImportacao?> abrirImportacao(
  BuildContext context, {
  Deck? deckDestino,
}) async {
  final opcao = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(deckDestino == null ? 'Importar deck' : 'Adicionar cards',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              deckDestino == null
                  ? 'Você revisa os cards antes de importar'
                  : 'Os cards entram em "${deckDestino.nome}"',
              style: const TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 12),
            _OpcaoImportacao(
              icone: Icons.upload_file,
              titulo: 'Arquivo',
              descricao: 'Anki (.apkg), Excel, CSV, TXT ou PDF',
              onTap: () => Navigator.of(sheetContext).pop('arquivo'),
            ),
            if (_temCamera)
              _OpcaoImportacao(
                icone: Icons.photo_camera_outlined,
                titulo: 'Tirar foto',
                descricao: 'De uma lista de vocabulário, caderno, livro…',
                onTap: () => Navigator.of(sheetContext).pop('camera'),
              ),
            _OpcaoImportacao(
              icone: Icons.photo_library_outlined,
              titulo: 'Escolher da galeria',
              descricao: 'Foto ou print com japonês e português',
              onTap: () => Navigator.of(sheetContext).pop('galeria'),
            ),
          ],
        ),
      ),
    ),
  );
  if (opcao == null || !context.mounted) return null;

  // 2. pega os bytes do arquivo/foto escolhido
  final _Escolhido? escolhido;
  try {
    escolhido = opcao == 'arquivo'
        ? await _escolherArquivo()
        : await _escolherFoto(
            opcao == 'camera' ? ImageSource.camera : ImageSource.gallery);
  } catch (e) {
    if (context.mounted) {
      _aviso(context, 'Não foi possível abrir ${opcao == 'camera' ? 'a câmera' : 'o arquivo'}.');
    }
    return null;
  }
  if (escolhido == null || !context.mounted) return null; // cancelou

  // 3. lê o conteúdo: arquivo → backend; foto → OCR no aparelho e o
  //    backend só separa japonês/português (ver _previaDaFoto)
  final previa = await _comCarregando(
    context,
    opcao == 'arquivo'
        ? 'Lendo o arquivo…'
        : kIsWeb
            ? 'Lendo a foto… (na primeira vez baixa o pacote de japonês)'
            : 'Lendo a foto…',
    opcao == 'arquivo'
        ? ApiService.previaImportacao(
            bytes: escolhido.bytes, nomeArquivo: escolhido.nome)
        : _previaDaFoto(escolhido),
  );
  if (previa == null || !context.mounted) return null;

  // 4. revisão: a tela de prévia grava e devolve o resultado
  return Navigator.of(context).push<ResultadoImportacao>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          PreviaImportacaoScreen(previa: previa, deckDestino: deckDestino),
    ),
  );
}

// Arquivo ou foto escolhidos. `caminho` só existe no celular/PC (no
// navegador só há os bytes); o ML Kit usa o caminho pra ler a foto.
typedef _Escolhido = ({Uint8List bytes, String nome, String? caminho});

// Foto → prévia. Primeiro tenta ler no PRÓPRIO APARELHO (Tesseract.js no
// navegador, ML Kit no celular) e manda só o texto pro backend separar.
// Se não der (ex.: app de Windows), manda a foto pro backend, que tenta o
// Tesseract instalado lá.
Future<PreviaImportacao> _previaDaFoto(_Escolhido foto) async {
  Object? erroAparelho;
  if (ocrNoAparelhoDisponivel) {
    try {
      final texto =
          await lerTextoDaFoto(bytes: foto.bytes, caminho: foto.caminho);
      return await ApiService.previaDeTexto(texto);
    } on ApiException {
      rethrow; // ex.: "Não consegui ler nenhum texto na foto" — já é a resposta
    } catch (e) {
      erroAparelho = e; // OCR do aparelho falhou: tenta o backend
    }
  }
  try {
    return await ApiService.previaImportacao(
        bytes: foto.bytes, nomeArquivo: foto.nome);
  } on ApiException {
    // os dois falharam: mostra o motivo mais útil
    if (erroAparelho != null) {
      throw ApiException(erroAparelho.toString().replaceFirst('Exception: ', ''));
    }
    rethrow;
  }
}

Future<_Escolhido?> _escolherArquivo() async {
  // file_picker 13: pickFile devolve null se o usuário cancelar
  final arquivo = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: _extensoesArquivo,
  );
  if (arquivo == null) return null;
  // lê os bytes (no navegador não existe caminho de arquivo, só os bytes)
  return (bytes: await arquivo.readAsBytes(), nome: arquivo.name, caminho: null);
}

Future<_Escolhido?> _escolherFoto(ImageSource fonte) async {
  final foto = await ImagePicker().pickImage(
    source: fonte,
    maxWidth: 2400, // foto de celular gigante só deixa o OCR mais lento
    imageQuality: 92,
  );
  if (foto == null) return null;
  var nome = foto.name;
  // no navegador o nome às vezes vem sem extensão; o backend decide o
  // formato pela extensão, então garante uma
  if (!RegExp(r'\.(png|jpe?g|webp|bmp|gif|tiff?)$', caseSensitive: false)
      .hasMatch(nome)) {
    nome = '$nome.jpg';
  }
  return (
    bytes: await foto.readAsBytes(),
    nome: nome,
    caminho: kIsWeb ? null : foto.path,
  );
}

// Mostra "Lendo…" enquanto a tarefa roda; se der erro, mostra a mensagem
// (ex.: "Tesseract não está instalado") e devolve null.
Future<T?> _comCarregando<T>(
    BuildContext context, String texto, Future<T> tarefa) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 16),
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    ),
  );
  try {
    final resultado = await tarefa;
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return resultado;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _aviso(context, e.toString());
    }
    return null;
  }
}

void _aviso(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(mensagem)));
}

class _OpcaoImportacao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  const _OpcaoImportacao({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.vermelhoClaro,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icone, color: AppColors.vermelho),
      ),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(descricao),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
