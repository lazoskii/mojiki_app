#testes automatizados do backend: importacao (RF11/RF12) e regras das rotas
#
#rodar (dentro da pasta backend):  venv\Scripts\python -m unittest -v
#
#usa um banco temporario (variavel MOJIKI_DB), entao NAO mexe no flashcards.db.
#os arquivos de exemplo (Anki, Excel, CSV) sao montados aqui mesmo, na hora.

import io
import json
import os
import sqlite3
import tempfile
import unittest
import zipfile

_pasta = tempfile.mkdtemp()
os.environ["MOJIKI_DB"] = os.path.join(_pasta, "teste.db")

import importador  # noqa: E402  (precisa vir depois de definir MOJIKI_DB)
import main  # noqa: E402
from fastapi import HTTPException  # noqa: E402
from models import (Cadastro, CardImportado, Flashcard, ImportarDeck, Login, LoteCards,  # noqa: E402
                    PedirRecuperacao, RedefinirSenha)

#usuario de teste: as rotas recebem o id do usuario logado (no app vem do token)
U = main.cadastrar(Cadastro(usuario="teste", email="teste@mojiki.com", senha="Senha123"))["id"]


def _banco_anki(esquema_novo=False) -> bytes:
    """Monta um banco do Anki minimo (tabelas notes + decks) e devolve os bytes."""
    caminho = os.path.join(_pasta, f"anki_{esquema_novo}.db")
    if os.path.exists(caminho):
        os.remove(caminho)
    conn = sqlite3.connect(caminho)
    conn.execute("CREATE TABLE notes (id INTEGER PRIMARY KEY, flds TEXT)")
    conn.executemany("INSERT INTO notes (flds) VALUES (?)", [
        ("水<br>(mizu)\x1fágua",),
        ("火\x1f<b>fogo</b>",),
        ("山\x1fmontanha [sound:yama.mp3]",),
    ])
    if esquema_novo:
        conn.execute("CREATE TABLE decks (id INTEGER, name TEXT)")
        conn.executemany("INSERT INTO decks VALUES (?, ?)", [(1, "Default"), (2, "Japonês\x1fNatureza")])
    else:
        conn.execute("CREATE TABLE col (decks TEXT)")
        conn.execute("INSERT INTO col VALUES (?)",
                     (json.dumps({"1": {"name": "Default"}, "2": {"name": "Natureza"}}),))
    conn.commit()
    conn.close()
    with open(caminho, "rb") as f:
        return f.read()


def _zip(arquivos: dict) -> bytes:
    saida = io.BytesIO()
    with zipfile.ZipFile(saida, "w") as z:
        for nome, dados in arquivos.items():
            z.writestr(nome, dados)
    return saida.getvalue()


class TestReconhecimentoJaponesPortugues(unittest.TestCase):
    def test_linha_com_separador(self):
        self.assertEqual(importador.separar_japones_portugues("水 (mizu) - água"), ("水 (mizu)", "água"))
        self.assertEqual(importador.separar_japones_portugues("おはよう;bom dia"), ("おはよう", "bom dia"))

    def test_linha_sem_separador(self):
        self.assertEqual(importador.separar_japones_portugues("水 (mizu) água"), ("水 (mizu)", "água"))
        self.assertEqual(importador.separar_japones_portugues("ありがとう obrigado"), ("ありがとう", "obrigado"))

    def test_linha_sem_japones_ou_sem_portugues(self):
        self.assertIsNone(importador.separar_japones_portugues("Lição 1 - Saudações"))
        self.assertIsNone(importador.separar_japones_portugues("こんにちは"))

    def test_linhas_alternadas_e_ignoradas(self):
        pares, ignoradas = importador.parear_linhas(
            ["Vocabulário", "犬", "cachorro", "猫 - gato", "12"])
        self.assertEqual(pares, [("犬", "cachorro"), ("猫", "gato")])
        self.assertEqual(ignoradas, 2)  # "Vocabulário" e "12"

    def test_sinais_de_menor_e_maior_nao_sao_html(self):
        self.assertEqual(importador.limpar("7 (ácido < 7, básico > 7)"), "7 (ácido < 7, básico > 7)")
        self.assertEqual(importador.limpar("<b>fogo</b> <span class='x'>quente</span>"), "fogo quente")

    def test_ocr_espacado_e_juntado(self):
        self.assertEqual(importador.limpar("水 は  água"), "水は água")


class TestFormatos(unittest.TestCase):
    def test_csv_com_cabecalho(self):
        previa = importador.gerar_previa("vocab.csv", "pergunta;resposta\n水;água\n火;fogo\n".encode())
        self.assertEqual(previa["cards"], [{"pergunta": "水", "resposta": "água"},
                                           {"pergunta": "火", "resposta": "fogo"}])
        self.assertEqual(previa["nome_sugerido"], "vocab")

    def test_csv_com_ponto_e_virgula_e_muitas_virgulas(self):
        # caso real: o csv.Sniffer achava que o separador era a virgula
        texto = ("Pergunta;Resposta\n"
                 "Biomas brasileiros;Amazônia, Cerrado, Caatinga, Mata Atlântica, Pampa e Pantanal\n"
                 "Blocos econômicos;Mercosul, União Europeia, USMCA\n"
                 "Clima equatorial;quente e úmido o ano todo\n")
        previa = importador.gerar_previa("geo.csv", texto.encode("utf-8-sig"))
        self.assertEqual(len(previa["cards"]), 3)
        self.assertEqual(previa["cards"][0]["pergunta"], "Biomas brasileiros")
        self.assertTrue(previa["cards"][0]["resposta"].startswith("Amazônia, Cerrado"))

    def test_csv_com_virgula(self):
        previa = importador.gerar_previa("en.csv", "dog,cachorro\ncat,gato\n".encode())
        self.assertEqual(previa["cards"][1], {"pergunta": "cat", "resposta": "gato"})

    def test_export_de_texto_do_anki(self):
        texto = "#separator:tab\n#html:true\n山\tmontanha\n川\trio\n"
        previa = importador.gerar_previa("Natureza.txt", texto.encode())
        self.assertEqual(len(previa["cards"]), 2)

    def test_texto_corrido(self):
        previa = importador.gerar_previa("anotacoes.txt", "犬\ncachorro\n猫 = gato\n".encode())
        self.assertEqual(len(previa["cards"]), 2)
        self.assertEqual(previa["cards"][1], {"pergunta": "猫", "resposta": "gato"})

    def test_excel(self):
        import openpyxl
        planilha = openpyxl.Workbook()
        aba = planilha.active
        for linha in [("Japonês", "Português"), ("本", "livro"), ("車", "carro"), (None, None)]:
            aba.append(linha)
        saida = io.BytesIO()
        planilha.save(saida)
        previa = importador.gerar_previa("lista.xlsx", saida.getvalue())
        self.assertEqual(previa["cards"], [{"pergunta": "本", "resposta": "livro"},
                                           {"pergunta": "車", "resposta": "carro"}])

    def test_anki_formato_antigo(self):
        previa = importador.gerar_previa("x.apkg", _zip({"collection.anki2": _banco_anki()}))
        self.assertEqual(previa["nome_sugerido"], "Natureza")
        self.assertEqual(previa["cards"][0], {"pergunta": "水 (mizu)", "resposta": "água"})
        self.assertEqual(previa["cards"][1]["resposta"], "fogo")       # sem <b>
        self.assertEqual(previa["cards"][2]["resposta"], "montanha")   # sem [sound:]

    def test_anki_formato_novo_zstd(self):
        import zstandard
        comprimido = zstandard.ZstdCompressor().compress(_banco_anki(esquema_novo=True))
        previa = importador.gerar_previa("x.apkg", _zip({"collection.anki21b": comprimido}))
        self.assertEqual(previa["nome_sugerido"], "Natureza")
        self.assertEqual(len(previa["cards"]), 3)

    def test_repetidos_sao_removidos(self):
        previa = importador.gerar_previa("a.csv", "水;água\n水;água\n".encode())
        self.assertEqual(len(previa["cards"]), 1)

    def test_formatos_recusados(self):
        for nome, dados in [("a.xls", b"x"), ("a.docx", b"x"), ("a.csv", b""), ("a.apkg", b"nao e zip")]:
            with self.assertRaises(importador.ErroImportacao):
                importador.gerar_previa(nome, dados)

    def test_foto_sem_tesseract_da_mensagem_clara(self):
        try:
            importador._configurar_tesseract().get_languages(config="")
            self.skipTest("Tesseract instalado nesta máquina")
        except Exception:
            pass
        with self.assertRaises(importador.ErroImportacao) as erro:
            importador.gerar_previa("foto.jpg", b"\xff\xd8\xff")
        self.assertIn("Tesseract", str(erro.exception))


class TestTextoDaFoto(unittest.TestCase):
    """RF12: OCR feito no aparelho, o backend so recebe o texto."""

    def test_texto_de_ocr_vira_cards(self):
        texto = "\n".join(["Vocabulário", "水 (mizu) - água", "火 は fogo", "山", "montanha"])
        previa = main.previa_texto(main.TextoImportado(texto=texto), U)
        self.assertEqual(previa["origem"], "foto")
        self.assertEqual([c["pergunta"] for c in previa["cards"]], ["水 (mizu)", "火は", "山"])
        self.assertEqual(previa["ignoradas"], 1)

    def test_texto_vazio_da_400(self):
        with self.assertRaises(HTTPException) as erro:
            main.previa_texto(main.TextoImportado(texto="   \n "), U)
        self.assertEqual(erro.exception.status_code, 400)


class TestRotas(unittest.TestCase):
    def test_importar_deck_cria_deck_e_cards(self):
        deck = main.importar_deck(ImportarDeck(nome="  Importado ", cards=[
            CardImportado(pergunta="本", resposta="livro"),
            CardImportado(pergunta="車", resposta="carro")]), U)
        self.assertEqual(deck["nome"], "Importado")
        self.assertEqual(deck["total_cards"], 2)
        self.assertEqual(len(main.buscar_deck(deck["id"], U)["cards"]), 2)

    def test_importar_com_card_vazio_nao_grava_nada(self):
        antes = len(main.listar_decks(U))
        with self.assertRaises(HTTPException):
            main.importar_deck(ImportarDeck(nome="Ruim", cards=[
                CardImportado(pergunta="本", resposta="livro"),
                CardImportado(pergunta="   ", resposta="x")]), U)
        self.assertEqual(len(main.listar_decks(U)), antes)  # rollback do deck inteiro

    def test_lote_em_deck_existente_e_inexistente(self):
        deck = main.importar_deck(ImportarDeck(nome="Lote", cards=[CardImportado(pergunta="一", resposta="um")]), U)
        criados = main.adicionar_lote(deck["id"], LoteCards(cards=[CardImportado(pergunta="二", resposta="dois")]), U)
        self.assertEqual(criados[0]["pergunta"], "二")
        self.assertEqual(main.adicionar_lote(99999, LoteCards(cards=criados and [CardImportado(pergunta="三", resposta="três")]), U),
                         {"erro": "Deck não encontrado"})

    def test_card_em_deck_inexistente(self):
        self.assertEqual(main.criar_flashcard(Flashcard(pergunta="p", resposta="r", deck_id=99999), U),
                         {"erro": "Deck não encontrado"})

    def test_excluir_deck_apaga_sessoes(self):
        from models import IniciarSessao
        deck = main.importar_deck(ImportarDeck(nome="Apagar", cards=[CardImportado(pergunta="一", resposta="um")]), U)
        main.iniciar_sessao(IniciarSessao(deck_id=deck["id"]), U)
        main.deletar_deck(deck["id"], U)
        restantes = [s for s in main.listar_sessoes(U) if s["deck_id"] == deck["id"]]
        self.assertEqual(restantes, [])


class TestLogin(unittest.TestCase):
    """Login com usuario e senha, recuperacao por e-mail e decks separados por usuario."""

    def _erro(self, funcao, *args):
        #roda a rota esperando HTTP 400/401 e devolve a mensagem
        with self.assertRaises(HTTPException) as erro:
            funcao(*args)
        return erro.exception.detail

    def test_regras_da_senha(self):
        for senha, trecho in [("Abc123", "8 caracteres"), ("Abcdefgh", "número"), ("abcdefg1", "maiúscula")]:
            self.assertIn(trecho, self._erro(main.cadastrar, Cadastro(usuario="regras", email="r@r.com", senha=senha)))

    def test_cadastro_login_e_token(self):
        conta = main.cadastrar(Cadastro(usuario="Ana.B", email="ANA@x.com", senha="Japones2026"))
        self.assertEqual(conta["email"], "ana@x.com")  #e-mail guardado em minusculas
        self.assertEqual(main.usuario_logado(f"Bearer {conta['token']}"), conta["id"])
        #usuario sem diferenciar maiusculas
        self.assertEqual(main.entrar(Login(usuario="ana.b", senha="Japones2026"))["id"], conta["id"])
        self.assertIn("incorretos", self._erro(main.entrar, Login(usuario="ana.b", senha="errada")))
        #nome e e-mail repetidos
        self.assertIn("usuário", self._erro(main.cadastrar, Cadastro(usuario="ANA.B", email="o@x.com", senha="Japones2026")))
        self.assertIn("e-mail", self._erro(main.cadastrar, Cadastro(usuario="outra", email="ana@X.com", senha="Japones2026")))
        #depois de sair, o token para de valer
        main.sair(f"Bearer {conta['token']}")
        self.assertEqual(401, self._status(main.usuario_logado, f"Bearer {conta['token']}"))

    def _status(self, funcao, *args):
        with self.assertRaises(HTTPException) as erro:
            funcao(*args)
        return erro.exception.status_code

    def test_sem_token_da_401(self):
        self.assertEqual(self._status(main.usuario_logado, None), 401)
        self.assertEqual(self._status(main.usuario_logado, "Bearer inventado"), 401)

    def test_recuperar_senha(self):
        conta = main.cadastrar(Cadastro(usuario="esqueci", email="esqueci@x.com", senha="Antiga123"))
        codigos = []
        original = main.auth.enviar_codigo_por_email
        main.auth.enviar_codigo_por_email = lambda email, usuario, codigo: codigos.append(codigo)
        try:
            main.pedir_recuperacao(PedirRecuperacao(email="esqueci@x.com"))
            main.pedir_recuperacao(PedirRecuperacao(email="naoexiste@x.com"))  #nao da erro
        finally:
            main.auth.enviar_codigo_por_email = original
        self.assertEqual(len(codigos), 1)

        errado = "000000" if codigos[0] != "000000" else "111111"
        self.assertIn("incorreto", self._erro(main.redefinir_senha, RedefinirSenha(
            email="esqueci@x.com", codigo=errado, nova_senha="Nova12345")))
        nova = main.redefinir_senha(RedefinirSenha(email="esqueci@x.com", codigo=codigos[0], nova_senha="Nova12345"))
        self.assertEqual(nova["id"], conta["id"])
        #token antigo derrubado, senha nova vale, codigo nao pode ser usado de novo
        self.assertEqual(self._status(main.usuario_logado, f"Bearer {conta['token']}"), 401)
        main.entrar(Login(usuario="esqueci", senha="Nova12345"))
        self.assertIn("expirado", self._erro(main.redefinir_senha, RedefinirSenha(
            email="esqueci@x.com", codigo=codigos[0], nova_senha="Outra12345")))

    def test_decks_separados_por_usuario(self):
        outro = main.cadastrar(Cadastro(usuario="outro", email="outro@x.com", senha="Outro1234"))["id"]
        deck = main.importar_deck(ImportarDeck(nome="Meu", cards=[CardImportado(pergunta="一", resposta="um")]), U)
        self.assertNotIn(deck["id"], [d["id"] for d in main.listar_decks(outro)])
        self.assertEqual(main.buscar_deck(deck["id"], outro), {"erro": "Deck não encontrado"})
        main.deletar_deck(deck["id"], outro)  #nao apaga o deck dos outros
        self.assertEqual(main.buscar_deck(deck["id"], U)["nome"], "Meu")


if __name__ == "__main__":
    unittest.main()
