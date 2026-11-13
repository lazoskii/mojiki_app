#API do Mojiki (FastAPI). Cada funcao com @app.<verbo>("/caminho") e uma rota.
#
#organizacao deste arquivo:
#  1. configuracao (app, CORS, tabelas)
#  2. FLASHCARDS     criar / listar / buscar / editar / excluir
#  3. DECKS          criar / listar / buscar / renomear / excluir
#  4. IMPORTACAO     previa de arquivo ou foto + gravar o que foi revisado
#  5. STUDY SESSIONS autoavaliacao (acertei/errei) e modos de estudo
#  6. FEEDBACK
#
#convencao de erros (o app trata os dois, ver ApiService._decodificar):
#  - dado invalido (campo vazio, modo invalido...) -> HTTP 400 com {"detail": "..."}
#  - registro nao encontrado -> HTTP 200 com {"erro": "..."} (formato antigo, mantido)

from datetime import datetime, timezone

#fastapi cria o servidor, "app" é a API
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from database import create_tables, get_connection
from importador import ErroImportacao, gerar_previa, gerar_previa_texto
from models import (Deck, EnviarFeedback, Flashcard, ImportarDeck, IniciarSessao,
                    LoteCards, RegistrarResposta, RenomearDeck, TextoImportado)

app = FastAPI()

#cria as tabelas automaticamente no banco
create_tables()

#CORS: deixa o app (que roda em outra porta/origem, ex.: Flutter web) chamar a API.
#allow_credentials fica False: o app nao usa cookies, e o navegador recusa
#"qualquer origem" (*) junto com credenciais.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # permite qualquer origem (ok pra desenvolvimento)
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


#data/hora atual em UTC no formato texto (datetime.utcnow() esta obsoleto no Python 3.12)
def agora_utc() -> str:
    return datetime.now(timezone.utc).isoformat()


#RF01/RF02: texto obrigatorio. Tira os espacos das pontas e devolve erro 400
#se sobrar string vazia (antes o backend aceitava deck/card em branco).
def obrigatorio(valor: str, campo: str) -> str:
    valor = valor.strip()
    if not valor:
        raise HTTPException(status_code=400, detail=f"O campo {campo} não pode ficar vazio")
    return valor


#confere se o deck existe antes de gravar cards nele (antes aceitava qualquer
#deck_id e criava cards "orfaos" que nunca apareciam no app)
def deck_existe(cursor, deck_id: int) -> bool:
    cursor.execute("SELECT 1 FROM decks WHERE id = ?", (deck_id,))
    return cursor.fetchone() is not None


# =========================
# FLASHCARDS
# =========================

#rota: criar flashcard
@app.post("/flashcards")
def criar_flashcard(card: Flashcard):  #usa model (pydantic)
    card.pergunta = obrigatorio(card.pergunta, "Pergunta")
    card.resposta = obrigatorio(card.resposta, "Resposta")

    conn = get_connection()
    cursor = conn.cursor()

    if not deck_existe(cursor, card.deck_id):
        conn.close()
        return {"erro": "Deck não encontrado"}

    cursor.execute(
        "INSERT INTO flashcards (pergunta, resposta, deck_id) VALUES (?, ?, ?)",
        (card.pergunta, card.resposta, card.deck_id)
    )

    conn.commit()
    novo_id = cursor.lastrowid  #pega o id gerado automaticamente
    conn.close()

    return {
        "id": novo_id,
        "pergunta": card.pergunta,
        "resposta": card.resposta,
        "deck_id": card.deck_id
    }


#rota: listar flashcards
@app.get("/flashcards")
def listar_flashcards():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM flashcards ORDER BY id")  #busca todos no banco
    cards = cursor.fetchall()

    conn.close()

    return [dict(card) for card in cards]  #converte pra json


#rota: buscar flashcard por id
@app.get("/flashcards/{id}")
def buscar_flashcard(id: int):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM flashcards WHERE id = ?", (id,))
    card = cursor.fetchone()

    conn.close()

    if not card:
        return {"erro": "Flashcard não encontrado"}

    return dict(card)


#rota: atualizar flashcard (semana 7 - RF06)
@app.put("/flashcards/{id}")
def atualizar_flashcard(id: int, card: Flashcard):
    card.pergunta = obrigatorio(card.pergunta, "Pergunta")
    card.resposta = obrigatorio(card.resposta, "Resposta")

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "UPDATE flashcards SET pergunta = ?, resposta = ?, deck_id = ? WHERE id = ?",
        (card.pergunta, card.resposta, card.deck_id, id)
    )

    #se nenhuma linha foi alterada, o id nao existe
    if cursor.rowcount == 0:
        conn.close()
        return {"erro": "Flashcard não encontrado"}

    conn.commit()
    conn.close()

    #devolve o card atualizado (o app usa pra atualizar a tela sem recarregar)
    return {
        "id": id,
        "pergunta": card.pergunta,
        "resposta": card.resposta,
        "deck_id": card.deck_id
    }


#rota: deletar flashcard
@app.delete("/flashcards/{id}")
def deletar_flashcard(id: int):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("DELETE FROM flashcards WHERE id = ?", (id,))

    conn.commit()
    conn.close()

    return {"msg": "Flashcard deletado"}


# =========================
# DECKS
# =========================

#rota: criar deck
@app.post("/decks")
def criar_deck(deck: Deck):
    deck.nome = obrigatorio(deck.nome, "Nome do deck")

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "INSERT INTO decks (nome, user_id) VALUES (?, ?)",
        (deck.nome, deck.user_id)
    )

    conn.commit()
    novo_id = cursor.lastrowid  #id automatico
    conn.close()

    return {
        "id": novo_id,
        "nome": deck.nome,
        "user_id": deck.user_id
    }


#rota: listar decks (em ordem de criacao)
@app.get("/decks")
def listar_decks():
    conn = get_connection()
    cursor = conn.cursor()

    #total_cards: quantidade de flashcards de cada deck (mostrada na Home)
    cursor.execute("""
        SELECT decks.*,
               (SELECT COUNT(*) FROM flashcards WHERE flashcards.deck_id = decks.id) AS total_cards
        FROM decks
        ORDER BY decks.id
    """)
    decks = cursor.fetchall()

    conn.close()

    return [dict(deck) for deck in decks]


#rota: buscar deck (com seus flashcards)
@app.get("/decks/{id}")
def buscar_deck(id: int):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM decks WHERE id = ?", (id,))
    deck = cursor.fetchone()

    if not deck:
        conn.close()
        return {"erro": "Deck não encontrado"}

    cursor.execute("SELECT * FROM flashcards WHERE deck_id = ? ORDER BY id", (id,))
    cards = cursor.fetchall()

    conn.close()

    return {
        **dict(deck),
        "cards": [dict(card) for card in cards]
    }


#rota: renomear deck (semana 8 - RF07)
@app.put("/decks/{id}")
def renomear_deck(id: int, deck: RenomearDeck):
    nome = obrigatorio(deck.nome, "Nome do deck")

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("UPDATE decks SET nome = ? WHERE id = ?", (nome, id))

    #se nenhuma linha foi alterada, o id nao existe
    if cursor.rowcount == 0:
        conn.close()
        return {"erro": "Deck não encontrado"}

    conn.commit()

    cursor.execute("SELECT * FROM decks WHERE id = ?", (id,))
    deck_atualizado = cursor.fetchone()

    conn.close()

    return dict(deck_atualizado)


#rota: deletar deck (junto com os cards e as sessoes de estudo dele)
@app.delete("/decks/{id}")
def deletar_deck(id: int):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("DELETE FROM flashcards WHERE deck_id = ?", (id,))
    cursor.execute("DELETE FROM study_sessions WHERE deck_id = ?", (id,))
    cursor.execute("DELETE FROM decks WHERE id = ?", (id,))

    conn.commit()
    conn.close()

    return {"msg": "Deck deletado"}


# =========================
# IMPORTACAO (RF11 arquivo / RF12 foto)
# =========================
#fluxo: 1) o app manda o arquivo pra /importar/previa e recebe os cards
#       encontrados (nada e gravado); 2) o usuario revisa no app;
#       3) o app manda so os cards aprovados pra /decks/importar (deck novo)
#       ou /decks/{id}/flashcards/lote (deck que ja existe).

#rota: ler arquivo (Anki, Excel, CSV, PDF) ou foto e devolver a previa
@app.post("/importar/previa")
async def previa_importacao(arquivo: UploadFile = File(...)):
    dados = await arquivo.read()
    try:
        return gerar_previa(arquivo.filename or "", dados)
    except ErroImportacao as e:
        raise HTTPException(status_code=400, detail=str(e))


#rota: previa a partir do TEXTO de uma foto ja lida no aparelho (RF12).
#o app faz o OCR la mesmo (ML Kit no celular, Tesseract.js no navegador) e
#manda so o texto -- assim nao precisa do Tesseract instalado no backend.
@app.post("/importar/texto")
def previa_texto(dados: TextoImportado):
    try:
        return gerar_previa_texto(dados.texto)
    except ErroImportacao as e:
        raise HTTPException(status_code=400, detail=str(e))


#grava uma lista de cards num deck, tudo numa transacao so
#(ou entram todos, ou nenhum). Devolve os cards criados com id.
def _gravar_cards(cursor, deck_id: int, cards) -> list:
    criados = []
    for card in cards:
        pergunta = obrigatorio(card.pergunta, "Pergunta")
        resposta = obrigatorio(card.resposta, "Resposta")
        cursor.execute(
            "INSERT INTO flashcards (pergunta, resposta, deck_id) VALUES (?, ?, ?)",
            (pergunta, resposta, deck_id)
        )
        criados.append({"id": cursor.lastrowid, "pergunta": pergunta,
                        "resposta": resposta, "deck_id": deck_id})
    return criados


#rota: criar um deck novo ja com os cards revisados
@app.post("/decks/importar")
def importar_deck(dados: ImportarDeck):
    nome = obrigatorio(dados.nome, "Nome do deck")
    if not dados.cards:
        raise HTTPException(status_code=400, detail="Selecione ao menos um card para importar")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO decks (nome, user_id) VALUES (?, ?)", (nome, dados.user_id))
        deck_id = cursor.lastrowid
        criados = _gravar_cards(cursor, deck_id, dados.cards)
        conn.commit()
    except HTTPException:
        conn.rollback()  #algum card vazio: desfaz o deck inteiro
        raise
    finally:
        conn.close()

    return {"id": deck_id, "nome": nome, "user_id": dados.user_id, "total_cards": len(criados)}


#rota: adicionar varios cards num deck que ja existe (foto -> cards dentro do deck)
@app.post("/decks/{id}/flashcards/lote")
def adicionar_lote(id: int, dados: LoteCards):
    if not dados.cards:
        raise HTTPException(status_code=400, detail="Selecione ao menos um card para importar")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        if not deck_existe(cursor, id):
            return {"erro": "Deck não encontrado"}
        criados = _gravar_cards(cursor, id, dados.cards)
        conn.commit()
    except HTTPException:
        conn.rollback()
        raise
    finally:
        conn.close()

    return criados


# =========================
# STUDY SESSIONS (autoavaliacao)
# =========================

#semana 10: modos aceitos (None = deck aberto direto da Home, sem modo)
MODOS_ESTUDO = (None, "rapida", "diaria", "intensiva")


#rota: iniciar uma sessao de estudo (comeca com acertos=0 e erros=0)
@app.post("/study-sessions")
def iniciar_sessao(sessao: IniciarSessao):
    if sessao.modo not in MODOS_ESTUDO:
        raise HTTPException(status_code=400, detail="Modo de estudo inválido")

    conn = get_connection()
    cursor = conn.cursor()

    agora = agora_utc()

    cursor.execute(
        "INSERT INTO study_sessions (user_id, deck_id, acertos, erros, iniciado_em, finalizado_em, modo) VALUES (?, ?, 0, 0, ?, NULL, ?)",
        (sessao.user_id, sessao.deck_id, agora, sessao.modo)
    )

    conn.commit()
    novo_id = cursor.lastrowid
    conn.close()

    return {
        "id": novo_id,
        "user_id": sessao.user_id,
        "deck_id": sessao.deck_id,
        "acertos": 0,
        "erros": 0,
        "iniciado_em": agora,
        "finalizado_em": None,
        "modo": sessao.modo
    }


#rota: GET para listar todas as sessoes de estudo
@app.get("/study-sessions")
def listar_sessoes():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM study_sessions ORDER BY id")
    sessoes = cursor.fetchall()

    conn.close()

    return [dict(sessao) for sessao in sessoes]


#rota: GET para buscar uma sessao de estudo pelo id
@app.get("/study-sessions/{id}")
def buscar_sessao(id: int):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM study_sessions WHERE id = ?", (id,))
    sessao = cursor.fetchone()

    conn.close()

    if not sessao:
        return {"erro": "Sessão de estudo não encontrada"}

    return dict(sessao)


#rota: registrar a resposta (acertei/errei) de um card estudado dentro de uma sessao
@app.post("/study-sessions/{id}/responder")
def registrar_resposta(id: int, resposta: RegistrarResposta):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM study_sessions WHERE id = ?", (id,))
    sessao = cursor.fetchone()

    if not sessao:
        conn.close()
        return {"erro": "Sessão de estudo não encontrada"}

    if sessao["finalizado_em"]:
        conn.close()
        return {"erro": "Sessão de estudo já foi finalizada"}

    if resposta.acerto:
        cursor.execute("UPDATE study_sessions SET acertos = acertos + 1 WHERE id = ?", (id,))
    else:
        cursor.execute("UPDATE study_sessions SET erros = erros + 1 WHERE id = ?", (id,))

    conn.commit()

    cursor.execute("SELECT * FROM study_sessions WHERE id = ?", (id,))
    sessao_atualizada = cursor.fetchone()

    conn.close()

    return dict(sessao_atualizada)


#rota: finalizar uma sessao de estudo
@app.put("/study-sessions/{id}/finalizar")
def finalizar_sessao(id: int):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM study_sessions WHERE id = ?", (id,))
    sessao = cursor.fetchone()

    if not sessao:
        conn.close()
        return {"erro": "Sessão de estudo não encontrada"}

    agora = agora_utc()

    cursor.execute("UPDATE study_sessions SET finalizado_em = ? WHERE id = ?", (agora, id))

    conn.commit()
    conn.close()

    return {"msg": "Sessão de estudo finalizada", "finalizado_em": agora}


# =========================
# FEEDBACK
# =========================

#rota: enviar feedback (opcao "Enviar feedback" no menu de perfil do app)
@app.post("/feedback")
def enviar_feedback(feedback: EnviarFeedback):
    mensagem = feedback.mensagem.strip()
    if not mensagem:
        raise HTTPException(status_code=400, detail="Mensagem de feedback vazia")

    conn = get_connection()
    cursor = conn.cursor()

    agora = agora_utc()
    cursor.execute(
        "INSERT INTO feedbacks (mensagem, criado_em) VALUES (?, ?)",
        (mensagem, agora)
    )

    conn.commit()
    novo_id = cursor.lastrowid
    conn.close()

    return {"id": novo_id, "mensagem": mensagem, "criado_em": agora}
