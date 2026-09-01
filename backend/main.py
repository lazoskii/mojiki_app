#fastapi cria o servidor, "app" é a API
from fastapi import FastAPI
from models import Flashcard, Deck, IniciarSessao, RegistrarResposta
from fastapi.middleware.cors import CORSMiddleware
from database import create_tables, get_connection
from datetime import datetime

app = FastAPI()

#cria as tabelas automaticamente no banco
create_tables()

app.add_middleware(           #adicionei isso pra nao dar erro no cors q tava
    CORSMiddleware,
    allow_origins=["*"],  # permite qualquer origem (ok pra desenvolvimento)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =========================
# FLASHCARDS
# =========================

#rota: criar flashcard
@app.post("/flashcards") 
def criar_flashcard(card: Flashcard):  #usa model (pydantic)
    conn = get_connection()
    cursor = conn.cursor()

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

    cursor.execute("SELECT * FROM flashcards")  #busca todos no banco
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


#rota: atualizar flashcard
@app.put("/flashcards/{id}")
def atualizar_flashcard(id: int, card: Flashcard):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "UPDATE flashcards SET pergunta = ?, resposta = ?, deck_id = ? WHERE id = ?",
        (card.pergunta, card.resposta, card.deck_id, id)
    )

    conn.commit()
    conn.close()

    return {"msg": "Flashcard atualizado"}


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


#rota: listar decks
@app.get("/decks")
def listar_decks():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM decks")
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

    cursor.execute("SELECT * FROM flashcards WHERE deck_id = ?", (id,))
    cards = cursor.fetchall()

    conn.close()

    return {
        **dict(deck),
        "cards": [dict(card) for card in cards]
    }


#rota: deletar deck (junto com os cards)
@app.delete("/decks/{id}")
def deletar_deck(id: int):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("DELETE FROM flashcards WHERE deck_id = ?", (id,))
    cursor.execute("DELETE FROM decks WHERE id = ?", (id,))

    conn.commit()
    conn.close()

    return {"msg": "Deck deletado"}



# study sessions para autoavaliacao


#rota: iniciar uma sessao de estudo (comeca com acertos=0 e erros=0)
@app.post("/study-sessions")
def iniciar_sessao(sessao: IniciarSessao):
    conn = get_connection()
    cursor = conn.cursor()

    agora = datetime.utcnow().isoformat()

    cursor.execute(
        "INSERT INTO study_sessions (user_id, deck_id, acertos, erros, iniciado_em, finalizado_em) VALUES (?, ?, 0, 0, ?, NULL)",
        (sessao.user_id, sessao.deck_id, agora)
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
        "finalizado_em": None
    }


#rota: GET para listar todas as sessoes de estudo
@app.get("/study-sessions")
def listar_sessoes():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM study_sessions")
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

    agora = datetime.utcnow().isoformat()

    cursor.execute("UPDATE study_sessions SET finalizado_em = ? WHERE id = ?", (agora, id))

    conn.commit()
    conn.close()

    return {"msg": "Sessão de estudo finalizada", "finalizado_em": agora}



