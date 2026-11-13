#importacao de decks (RF11) e foto -> cards (RF12)
#
#esse arquivo so LE os arquivos e devolve uma "previa": uma lista de pares
#{pergunta, resposta}. Nada e gravado no banco aqui -- o app mostra a previa,
#o usuario revisa (desmarca, edita, inverte) e so depois chama a rota que
#grava (POST /decks/importar ou POST /decks/{id}/flashcards/lote, no main.py).
#
#formatos aceitos:
#  .apkg / .colpkg  -> pacote do Anki (zip com um banco SQLite dentro)
#  .csv / .tsv / .txt -> texto em colunas (inclusive o "exportar como texto" do Anki)
#  .xlsx            -> Excel (planilha nova; .xls antigo nao)
#  .pdf             -> texto do PDF; se for escaneado (so imagem), tenta OCR
#  .png/.jpg/...    -> foto: OCR com Tesseract (japones + portugues)
#
#regra de "reconhecer japones e portugues" (PDF, foto e texto solto):
#  - uma linha com japones E portugues vira um card (ex.: "水 (mizu) - agua")
#  - uma linha so em japones seguida de uma linha so em portugues tambem
#  - o lado em japones vira a PERGUNTA e o lado em portugues a RESPOSTA

import csv
import html
import io
import json
import os
import re
import sqlite3
import tempfile
import zipfile
from pathlib import Path

LIMITE_CARDS = 2000  #evita travar o app com um arquivo gigante
LIMITE_BYTES = 20 * 1024 * 1024  #20 MB

EXTENSOES_IMAGEM = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".tif", ".tiff"}

#hiragana, katakana, kanji (CJK), katakana de meia largura, 々 e ー
_JAPONES = re.compile(r"[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uff66-\uff9f\u3005]")
_LETRA_LATINA = re.compile(r"[A-Za-zÀ-ÿ]")
#separadores comuns entre os dois lados numa mesma linha
_SEPARADORES = re.compile(r"\t+|\s+[-–—=:|→>]+\s+|\s*[=:|→]\s*|\s*;\s*")
#cabecalhos tipicos de planilha (primeira linha que deve ser pulada)
_CABECALHOS = {"pergunta", "resposta", "frente", "verso", "front", "back",
               "japones", "japonês", "portugues", "português", "palavra",
               "significado", "kanji", "leitura", "traducao", "tradução"}


class ErroImportacao(Exception):
    """Erro com mensagem pronta pra mostrar ao usuario (vira HTTP 400)."""


# =========================
# AJUDANTES DE TEXTO
# =========================

def tem_japones(texto: str) -> bool:
    return bool(_JAPONES.search(texto))


def tem_letras(texto: str) -> bool:
    return bool(_LETRA_LATINA.search(texto))


def limpar(texto) -> str:
    """Tira HTML (o Anki guarda os campos em HTML), [sound:...] e espacos extras."""
    if texto is None:
        return ""
    texto = str(texto)
    texto = re.sub(r"\[sound:[^\]]*\]", " ", texto)
    texto = re.sub(r"<br\s*/?>|<div>|</div>|<p>|</p>", " ", texto, flags=re.I)
    #so remove o que parece tag HTML (<b>, </div>, <span ...>); antes qualquer
    #trecho entre < e > sumia, ex.: "7 (ácido < 7, básico > 7)" virava "7 (ácido  7)"
    texto = re.sub(r"</?[A-Za-z][^<>]*>", "", texto)
    texto = html.unescape(texto).replace("\xa0", " ")
    #o OCR coloca espaco entre cada caractere japones ("水 は") -> junta
    texto = re.sub(r"(?<=[\u3040-\u30ff\u3400-\u9fff])\s+(?=[\u3040-\u30ff\u3400-\u9fff])", "", texto)
    return re.sub(r"\s+", " ", texto).strip()


def separar_japones_portugues(linha: str):
    """Tenta achar (japones, portugues) numa linha so. Devolve None se nao der."""
    linha = limpar(linha)
    if not linha or not tem_japones(linha) or not tem_letras(linha):
        return None

    #1) linha com separador: "水 - agua", "水;agua", "水 = agua"...
    partes = [p.strip() for p in _SEPARADORES.split(linha) if p and p.strip()]
    if len(partes) >= 2:
        jp = [p for p in partes if tem_japones(p)]
        pt = [p for p in partes if not tem_japones(p) and tem_letras(p)]
        if jp and pt:
            #romaji entre parenteses logo depois do japones fica junto da pergunta
            return " ".join(jp), " ".join(pt)

    #2) sem separador: "水 (mizu) agua" -> corta depois do ultimo caractere japones
    ultimo = max(m.end() for m in _JAPONES.finditer(linha))
    jp, resto = linha[:ultimo].strip(), linha[ultimo:].strip()
    romaji = re.match(r"^\(([^)]*)\)\s*", resto)
    if romaji:
        jp = f"{jp} ({romaji.group(1).strip()})"
        resto = resto[romaji.end():]
    resto = resto.strip(" -–—=:;|,.")
    #(resto nunca tem japones: o corte foi no ULTIMO caractere japones)
    if jp and resto and tem_letras(resto):
        return jp, resto
    return None


def parear_linhas(linhas):
    """Transforma linhas soltas (PDF, OCR, texto) em pares japones/portugues.

    Devolve (pares, ignoradas): ignoradas = linhas com conteudo que nao
    viraram card (titulos, numeros de pagina...), pra avisar o usuario.
    """
    pares, ignoradas = [], 0
    japones_pendente = None  #linha so em japones esperando a traducao

    for bruta in linhas:
        linha = limpar(bruta)
        if not linha:
            continue
        par = separar_japones_portugues(linha)
        if par:
            if japones_pendente:
                ignoradas += 1
            pares.append(par)
            japones_pendente = None
        elif tem_japones(linha) and not tem_letras(linha):
            if japones_pendente:
                ignoradas += 1
            japones_pendente = linha
        elif japones_pendente and tem_letras(linha):
            pares.append((japones_pendente, linha))
            japones_pendente = None
        else:
            ignoradas += 1

    if japones_pendente:
        ignoradas += 1
    return pares, ignoradas


def _pares_de_tabela(linhas_tabela):
    """Planilha/CSV/Anki: primeira coluna = pergunta, segunda = resposta.

    Se a linha so tem uma coluna preenchida, tenta separar japones/portugues
    dentro dela (ex.: "水 - agua" numa celula so).
    """
    pares, ignoradas = [], 0
    for i, linha in enumerate(linhas_tabela):
        celulas = [limpar(c) for c in linha if limpar(c)]
        if not celulas:
            continue
        if i == 0 and all(c.lower() in _CABECALHOS for c in celulas[:2]):
            continue  #cabecalho "Pergunta | Resposta"
        if celulas[0].startswith("#"):
            continue  #linhas de configuracao do export do Anki (#separator:tab)
        if len(celulas) >= 2:
            pares.append((celulas[0], celulas[1]))
            continue
        par = separar_japones_portugues(celulas[0])
        if par:
            pares.append(par)
        else:
            ignoradas += 1
    return pares, ignoradas


# =========================
# LEITORES POR FORMATO
# =========================

def _ler_anki(dados: bytes):
    """Pacote .apkg/.colpkg: zip com o banco do Anki (SQLite) dentro.

    Versoes novas do Anki gravam "collection.anki21b" comprimido com zstd;
    as antigas, "collection.anki21"/"collection.anki2" direto.
    """
    try:
        pacote = zipfile.ZipFile(io.BytesIO(dados))
    except zipfile.BadZipFile:
        raise ErroImportacao("Arquivo do Anki inválido ou corrompido.")

    nomes = set(pacote.namelist())
    banco = None
    if "collection.anki21b" in nomes:
        try:
            import zstandard
            banco = zstandard.ZstdDecompressor().stream_reader(
                io.BytesIO(pacote.read("collection.anki21b"))).read()
        except ImportError:
            pass
    if banco is None:
        for nome in ("collection.anki21", "collection.anki2"):
            if nome in nomes:
                banco = pacote.read(nome)
                break
    if banco is None:
        raise ErroImportacao("Não achei os cards dentro do arquivo do Anki.")

    #o sqlite3 do Python so abre arquivo, entao grava num temporario
    with tempfile.TemporaryDirectory() as pasta:
        caminho = os.path.join(pasta, "colecao.db")
        Path(caminho).write_bytes(banco)
        conn = sqlite3.connect(caminho)
        try:
            notas = [r[0] for r in conn.execute("SELECT flds FROM notes")]
            nome_deck = _nome_deck_anki(conn)
        finally:
            conn.close()

    #cada nota guarda os campos separados pelo caractere \x1f
    linhas = [n.split("\x1f") for n in notas]
    if any("please update to the latest anki" in limpar(c).lower() for l in linhas for c in l):
        raise ErroImportacao(
            "Esse arquivo foi exportado num formato novo do Anki. Exporte de novo "
            "marcando \"Suporte a versões antigas do Anki\".")
    pares, ignoradas = _pares_de_tabela(linhas)
    return pares, ignoradas, nome_deck


def _nome_deck_anki(conn):
    """Nome do deck dentro do Anki (pula o deck "Default"/"Padrão")."""
    nomes = []
    try:  #esquema novo: tabela decks
        nomes = [r[0] for r in conn.execute("SELECT name FROM decks")]
    except sqlite3.Error:
        try:  #esquema antigo: JSON na tabela col
            decks = json.loads(conn.execute("SELECT decks FROM col").fetchone()[0])
            nomes = [d.get("name", "") for d in decks.values()]
        except Exception:
            nomes = []
    nomes = [n.replace("\x1f", "::") for n in nomes if n and n.lower() not in ("default", "padrão", "padrao")]
    return nomes[0].split("::")[-1] if nomes else None


def _decodificar_texto(dados: bytes) -> str:
    for codificacao in ("utf-8-sig", "utf-16", "cp1252"):
        try:
            return dados.decode(codificacao)
        except UnicodeDecodeError:
            continue
    return dados.decode("latin-1")


def _detectar_separador(texto: str):
    """Descobre o separador das colunas (tab, ;, | ou ,).

    Escolhe o que divide as linhas de forma mais CONSISTENTE (o mesmo numero
    de colunas em quase todas). Antes usava o csv.Sniffer, que errava em
    arquivos com ";" e muitas virgulas dentro do texto ("Amazonia, Cerrado,
    Caatinga") -- comum em CSV exportado do Excel em portugues.
    Devolve None se nenhum separador formar colunas (texto corrido).
    """
    linhas = [l for l in texto.splitlines()[:50] if l.strip() and not l.startswith("#")]
    melhor, melhor_nota = None, 0.0
    for sep in ("\t", ";", "|", ","):  #empate: vence o que vem primeiro
        contagens = [len(l) for l in csv.reader(linhas, delimiter=sep)]
        if not contagens:
            continue
        moda = max(set(contagens), key=contagens.count)
        nota = contagens.count(moda) / len(contagens)
        if moda >= 2 and nota > melhor_nota:
            melhor, melhor_nota = sep, nota
    return melhor if melhor_nota >= 0.6 else None


def _ler_texto(dados: bytes):
    """CSV / TSV / TXT. Descobre o separador sozinho (tab, ;, | ou ,)."""
    texto = _decodificar_texto(dados)
    separador = _detectar_separador(texto)
    if separador:
        return _pares_de_tabela(list(csv.reader(io.StringIO(texto), delimiter=separador)))
    #sem colunas: texto corrido -> regra japones/portugues linha a linha
    return parear_linhas(texto.splitlines())


def _ler_excel(dados: bytes):
    try:
        import openpyxl
    except ImportError:
        raise ErroImportacao("Importar Excel precisa do pacote openpyxl no backend.")
    try:
        planilha = openpyxl.load_workbook(io.BytesIO(dados), read_only=True, data_only=True)
    except Exception:
        raise ErroImportacao("Não consegui abrir a planilha. Salve como .xlsx ou .csv.")
    aba = planilha.worksheets[0]
    linhas = [["" if c is None else str(c) for c in linha] for linha in aba.iter_rows(values_only=True)]
    planilha.close()
    return _pares_de_tabela(linhas)


def _ler_pdf(dados: bytes, avisos):
    try:
        from pypdf import PdfReader
    except ImportError:
        raise ErroImportacao("Importar PDF precisa do pacote pypdf no backend.")
    try:
        leitor = PdfReader(io.BytesIO(dados))
        paginas = list(leitor.pages)
    except Exception:
        raise ErroImportacao("Não consegui abrir o PDF.")

    linhas = []
    for pagina in paginas:
        linhas.extend((pagina.extract_text() or "").splitlines())

    if any(l.strip() for l in linhas):
        return parear_linhas(linhas)

    #PDF sem texto = escaneado (cada pagina e uma imagem) -> tenta OCR nas imagens
    avisos.append("O PDF não tem texto (parece escaneado); usei leitura de imagem (OCR).")
    for pagina in paginas:
        for imagem in getattr(pagina, "images", []):
            linhas.extend(ocr_imagem(imagem.data, avisos).splitlines())
    return parear_linhas(linhas)


# =========================
# OCR (foto -> texto)
# =========================

def _configurar_tesseract():
    """Acha o executavel do Tesseract (no Windows ele nao entra no PATH sozinho)."""
    import pytesseract
    caminho = os.environ.get("TESSERACT_CMD")
    padrao_windows = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
    if caminho:
        pytesseract.pytesseract.tesseract_cmd = caminho
    elif os.path.exists(padrao_windows):
        pytesseract.pytesseract.tesseract_cmd = padrao_windows
    return pytesseract


def ocr_imagem(dados: bytes, avisos) -> str:
    """Le o texto de uma imagem com Tesseract (japones + portugues)."""
    try:
        from PIL import Image, ImageOps
        pytesseract = _configurar_tesseract()
    except ImportError:
        raise ErroImportacao("A leitura de fotos precisa dos pacotes Pillow e pytesseract no backend.")

    try:
        idiomas = set(pytesseract.get_languages(config=""))
    except Exception:
        raise ErroImportacao(
            "Leitura de fotos indisponível: o Tesseract não está instalado no computador "
            "do backend. Veja \"Como rodar\" no README.")

    #"por" antes de "jpn": na ordem contraria o Tesseract perde os acentos
    #do portugues ("agua" em vez de "água") -- testado com o Tesseract.js
    usar = [l for l in ("por", "jpn") if l in idiomas]
    if "jpn" not in idiomas:
        avisos.append("O Tesseract está sem o pacote de japonês (jpn); o texto em japonês pode não ser lido.")
    if not usar:
        usar = ["eng"]

    try:
        imagem = Image.open(io.BytesIO(dados))
    except Exception:
        raise ErroImportacao("Não consegui abrir a imagem.")

    #pre-processamento simples que ajuda bastante com foto de celular:
    #desvira pela EXIF, tons de cinza, contraste automatico e aumenta se for pequena
    imagem = ImageOps.exif_transpose(imagem).convert("L")
    imagem = ImageOps.autocontrast(imagem)
    if max(imagem.size) < 1500:
        fator = 1500 / max(imagem.size)
        imagem = imagem.resize((int(imagem.width * fator), int(imagem.height * fator)))

    #psm 6 = "um bloco de texto uniforme" (bom pra listas de vocabulario)
    return pytesseract.image_to_string(imagem, lang="+".join(usar), config="--psm 6")


# =========================
# ENTRADA PRINCIPAL
# =========================

def gerar_previa(nome_arquivo: str, dados: bytes) -> dict:
    """Le o arquivo e devolve a previa: nome sugerido, cards e avisos."""
    if not dados:
        raise ErroImportacao("O arquivo está vazio.")
    if len(dados) > LIMITE_BYTES:
        raise ErroImportacao("Arquivo grande demais (máximo 20 MB).")

    extensao = Path(nome_arquivo or "").suffix.lower()
    nome_sugerido = Path(nome_arquivo or "Deck importado").stem.replace("_", " ").strip()
    avisos = []

    if extensao in (".apkg", ".colpkg"):
        pares, ignoradas, nome_anki = _ler_anki(dados)
        nome_sugerido = nome_anki or nome_sugerido
        origem = "anki"
    elif extensao in (".csv", ".tsv", ".txt"):
        pares, ignoradas = _ler_texto(dados)
        origem = "texto"
    elif extensao == ".xlsx":
        pares, ignoradas = _ler_excel(dados)
        origem = "excel"
    elif extensao == ".xls":
        raise ErroImportacao("Formato .xls antigo não é suportado. Salve a planilha como .xlsx ou .csv.")
    elif extensao == ".pdf":
        pares, ignoradas = _ler_pdf(dados, avisos)
        origem = "pdf"
    elif extensao in EXTENSOES_IMAGEM:
        texto = ocr_imagem(dados, avisos)
        pares, ignoradas = parear_linhas(texto.splitlines())
        origem = "foto"
        nome_sugerido = "Deck da foto"
    else:
        raise ErroImportacao(
            "Formato não suportado. Use Anki (.apkg), Excel (.xlsx), CSV/TXT, PDF ou uma foto.")

    return _montar_previa(pares, ignoradas, nome_sugerido, origem, avisos)


def gerar_previa_texto(texto: str) -> dict:
    """Previa a partir de TEXTO ja lido no aparelho (OCR feito no proprio app:
    ML Kit no celular, Tesseract.js no navegador). So aplica a regra
    japones/portugues -- nao precisa do Tesseract instalado no backend."""
    if not texto or not texto.strip():
        raise ErroImportacao("Não consegui ler nenhum texto na foto. Tente uma foto mais nítida e reta.")
    if len(texto) > 200_000:
        raise ErroImportacao("Texto grande demais.")
    pares, ignoradas = parear_linhas(texto.splitlines())
    return _montar_previa(pares, ignoradas, "Deck da foto", "foto", [])


def _montar_previa(pares, ignoradas, nome_sugerido, origem, avisos) -> dict:
    """Parte comum: limpa, tira repetidos, aplica o limite e monta a resposta."""
    #remove repetidos (mesma pergunta e resposta) mantendo a ordem
    vistos, cards = set(), []
    for pergunta, resposta in pares:
        pergunta, resposta = limpar(pergunta)[:500], limpar(resposta)[:500]
        chave = (pergunta, resposta)
        if pergunta and resposta and chave not in vistos:
            vistos.add(chave)
            cards.append({"pergunta": pergunta, "resposta": resposta})

    if len(cards) > LIMITE_CARDS:
        avisos.append(f"O arquivo tinha {len(cards)} cards; importei só os {LIMITE_CARDS} primeiros.")
        cards = cards[:LIMITE_CARDS]
    if not cards:
        avisos.append("Não encontrei pares de pergunta/resposta. No PDF e na foto, cada linha "
                      "precisa ter a palavra em japonês e a tradução (ou uma linha de cada).")

    return {
        "nome_sugerido": nome_sugerido[:80] or "Deck importado",
        "origem": origem,
        "cards": cards,
        "ignoradas": ignoradas,
        "avisos": avisos,
    }
