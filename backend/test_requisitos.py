#testes que comprovam os requisitos basicos do README (RF01-RF08 + Bloco 1)
#do lado do servidor. Cada classe e um requisito; cada teste e um caso de
#teste (CT) de docs/casos_de_teste.md virado em codigo.
#
#rodar (dentro da pasta backend):
#   venv\Scripts\python -m unittest test_requisitos -v
#
#mesmo esquema do test_backend.py: banco temporario (MOJIKI_DB) e as rotas
#chamadas direto, passando o id do usuario no lugar do token.

import os
import tempfile
import unittest

os.environ["MOJIKI_DB"] = os.path.join(tempfile.mkdtemp(), "requisitos.db")

import main  # noqa: E402  (precisa vir depois de definir MOJIKI_DB)
from fastapi import HTTPException  # noqa: E402
from models import (Cadastro, Deck, Flashcard, IniciarSessao,  # noqa: E402
                    RegistrarResposta, RenomearDeck)

U = main.cadastrar(Cadastro(usuario="requisitos", email="req@mojiki.com", senha="Senha123"))["id"]


def novo_deck(nome="Japonês", cards=()):
    """Cria um deck com os cards (pergunta, resposta) e devolve o id."""
    deck_id = main.criar_deck(Deck(nome=nome), U)["id"]
    for pergunta, resposta in cards:
        main.criar_flashcard(Flashcard(pergunta=pergunta, resposta=resposta, deck_id=deck_id), U)
    return deck_id


class Base(unittest.TestCase):
    def assert400(self, funcao, *args):
        """A rota tem que recusar com HTTP 400; devolve a mensagem."""
        with self.assertRaises(HTTPException) as erro:
            funcao(*args)
        self.assertEqual(erro.exception.status_code, 400)
        return erro.exception.detail


class TestRF01NomeDoDeck(Base):
    def test_nome_vazio_ou_so_espacos_e_recusado(self):
        antes = len(main.listar_decks(U))
        for nome in ["", "   ", "\t\n"]:
            self.assertIn("Nome do deck", self.assert400(main.criar_deck, Deck(nome=nome), U))
        self.assertEqual(len(main.listar_decks(U)), antes)  #nada foi gravado

    def test_nome_valido_e_gravado_sem_espacos_nas_pontas(self):
        deck = main.criar_deck(Deck(nome="  Kanji N5  "), U)
        self.assertEqual(deck["nome"], "Kanji N5")
        self.assertIn(deck["id"], [d["id"] for d in main.listar_decks(U)])

    def test_renomear_para_vazio_e_recusado(self):
        deck_id = novo_deck("Original")
        self.assert400(main.renomear_deck, deck_id, RenomearDeck(nome="  "), U)
        self.assertEqual(main.buscar_deck(deck_id, U)["nome"], "Original")


class TestRF02PerguntaEResposta(Base):
    def test_criar_card_com_campo_vazio_e_recusado(self):
        deck_id = novo_deck()
        self.assertIn("Pergunta", self.assert400(
            main.criar_flashcard, Flashcard(pergunta=" ", resposta="água", deck_id=deck_id), U))
        self.assertIn("Resposta", self.assert400(
            main.criar_flashcard, Flashcard(pergunta="水", resposta="", deck_id=deck_id), U))
        self.assertEqual(main.buscar_deck(deck_id, U)["cards"], [])

    def test_editar_card_para_vazio_e_recusado(self):
        deck_id = novo_deck(cards=[("水", "água")])
        card = main.buscar_deck(deck_id, U)["cards"][0]
        self.assert400(main.atualizar_flashcard, card["id"],
                       Flashcard(pergunta="水", resposta="  ", deck_id=deck_id), U)
        self.assertEqual(main.buscar_flashcard(card["id"], U)["resposta"], "água")


class TestRF04ExcluirDeck(Base):
    def test_excluir_deck_apaga_os_cards_e_as_sessoes_dele(self):
        deck_id = novo_deck(cards=[("水", "água"), ("火", "fogo")])
        outro_id = novo_deck("Outro", cards=[("山", "montanha")])
        cards = [c["id"] for c in main.buscar_deck(deck_id, U)["cards"]]
        main.iniciar_sessao(IniciarSessao(deck_id=deck_id), U)

        main.deletar_deck(deck_id, U)

        self.assertEqual(main.buscar_deck(deck_id, U), {"erro": "Deck não encontrado"})
        for card_id in cards:
            self.assertEqual(main.buscar_flashcard(card_id, U), {"erro": "Flashcard não encontrado"})
        self.assertNotIn(deck_id, [s["deck_id"] for s in main.listar_sessoes(U)])
        self.assertEqual(len(main.buscar_deck(outro_id, U)["cards"]), 1)  #outro deck intacto


class TestRF05ExcluirFlashcard(Base):
    def test_excluir_card_apaga_so_ele(self):
        deck_id = novo_deck(cards=[("水", "água"), ("火", "fogo")])
        primeiro, segundo = main.buscar_deck(deck_id, U)["cards"]
        main.deletar_flashcard(primeiro["id"], U)
        restantes = main.buscar_deck(deck_id, U)["cards"]
        self.assertEqual([c["id"] for c in restantes], [segundo["id"]])


class TestRF06EditarFlashcard(Base):
    def test_edicao_e_persistida(self):
        deck_id = novo_deck(cards=[("水", "agua")])
        card_id = main.buscar_deck(deck_id, U)["cards"][0]["id"]
        resposta = main.atualizar_flashcard(card_id, Flashcard(pergunta="水", resposta="água", deck_id=deck_id), U)
        self.assertEqual(resposta["resposta"], "água")
        #relendo do banco (o que o app ve ao reabrir o deck)
        self.assertEqual(main.buscar_flashcard(card_id, U)["resposta"], "água")

    def test_card_inexistente_responde_erro(self):
        deck_id = novo_deck()
        self.assertEqual(main.atualizar_flashcard(99999, Flashcard(pergunta="a", resposta="b", deck_id=deck_id), U),
                         {"erro": "Flashcard não encontrado"})


class TestRF07RenomearDeck(Base):
    def test_renomear_mantem_os_cards(self):
        deck_id = novo_deck("Matematica", cards=[("2 + 2", "4")])
        self.assertEqual(main.renomear_deck(deck_id, RenomearDeck(nome="Matemática"), U)["nome"], "Matemática")
        deck = main.buscar_deck(deck_id, U)
        self.assertEqual(deck["nome"], "Matemática")
        self.assertEqual(len(deck["cards"]), 1)

    def test_deck_inexistente_responde_erro(self):
        self.assertEqual(main.renomear_deck(99999, RenomearDeck(nome="X"), U), {"erro": "Deck não encontrado"})


class TestBloco1Autoavaliacao(Base):
    """Acertei/Errei: a sessao comeca zerada, conta cada resposta e e finalizada."""

    def test_fluxo_completo_acertos_erros_e_finalizacao(self):
        deck_id = novo_deck(cards=[("水", "água"), ("火", "fogo"), ("山", "montanha")])
        sessao = main.iniciar_sessao(IniciarSessao(deck_id=deck_id), U)
        self.assertEqual((sessao["acertos"], sessao["erros"], sessao["finalizado_em"]), (0, 0, None))

        for acerto in (True, True, False):
            main.registrar_resposta(sessao["id"], RegistrarResposta(acerto=acerto), U)
        main.finalizar_sessao(sessao["id"], U)

        gravada = main.buscar_sessao(sessao["id"], U)  #conferido no banco
        self.assertEqual((gravada["acertos"], gravada["erros"]), (2, 1))
        self.assertIsNotNone(gravada["finalizado_em"])

    def test_sessao_finalizada_nao_aceita_resposta(self):
        sessao = main.iniciar_sessao(IniciarSessao(deck_id=novo_deck()), U)
        main.finalizar_sessao(sessao["id"], U)
        self.assertEqual(main.registrar_resposta(sessao["id"], RegistrarResposta(acerto=True), U),
                         {"erro": "Sessão de estudo já foi finalizada"})
        self.assertEqual(main.buscar_sessao(sessao["id"], U)["acertos"], 0)

    def test_sessao_ou_deck_inexistente(self):
        self.assertEqual(main.registrar_resposta(99999, RegistrarResposta(acerto=True), U),
                         {"erro": "Sessão de estudo não encontrada"})
        self.assertEqual(main.iniciar_sessao(IniciarSessao(deck_id=99999), U), {"erro": "Deck não encontrado"})


class TestRF08ModosDeEstudo(Base):
    def test_cada_modo_e_gravado_na_sessao(self):
        deck_id = novo_deck(cards=[("水", "água")])
        for modo in ("rapida", "diaria", "intensiva", None):
            sessao = main.iniciar_sessao(IniciarSessao(deck_id=deck_id, modo=modo), U)
            self.assertEqual(main.buscar_sessao(sessao["id"], U)["modo"], modo)

    def test_modo_invalido_e_recusado(self):
        deck_id = novo_deck()
        antes = len(main.listar_sessoes(U))
        self.assertIn("Modo", self.assert400(main.iniciar_sessao, IniciarSessao(deck_id=deck_id, modo="turbo"), U))
        self.assertEqual(len(main.listar_sessoes(U)), antes)


if __name__ == "__main__":
    unittest.main()
