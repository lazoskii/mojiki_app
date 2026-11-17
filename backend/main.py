#API do Mojiki (FastAPI). Cada funcao com @app.<verbo>("/caminho") e uma rota.
#
#organizacao deste arquivo:
#  1. configuracao (app, CORS, tabelas)
#  2. FLASHCARDS     criar / listar / buscar / editar / excluir
#  3. DECKS          criar / listar / buscar / renomear / excluir
#  4. IMPORTACAO     previa de arquivo ou foto + gravar o que foi revisado
#  5. STUDY SESSIONS autoavaliacao (acertei/errei) e modos de estudo
#  6. FEEDBACK
#  7. LOGIN          cadastro / login / sair / recuperar senha
#
#autenticacao: quase todas as rotas recebem `usuario_id = Depends(usuario_logado)`.
#o app manda o token no cabecalho "Authorization: Bearer <token>"; sem token
#valido a rota responde 401 e o app volta pra tela de login.
#cada usuario so enxerga os proprios decks, cards e sessoes.
#
#convencao de erros (o app trata os dois, ver ApiService._decodificar):
#  - dado invalido (campo vazio, modo invalido...) -> HTTP 400 com {"detail": "..."}
#  - registro nao encontrado -> HTTP 200 com {"erro": "..."} (formato antigo, mantido)

from datetime import datetime, timedelta, timezone

#fastapi cria o servidor, "app" é a API
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

import os

import auth
from database import create_tables, get_connection
from importador import ErroImportacao, gerar_previa, gerar_previa_texto
from models import (Cadastro, Deck, EnviarFeedback, Flashcard, ImportarDeck, IniciarSessao,
                    Login, LoteCards, PedirRecuperacao, RedefinirSenha, RegistrarResposta,
                    RenomearDeck, TextoImportado)

app = FastAPI()

#cria as tabelas automaticamente no banco
create_tables()

#contas fixas de demonstracao (professor + alunos N5..N1): so quando pedido,
#ex.: rodando no PC pelo rodar_local.bat. O Render nao liga isso.
if os.environ.get("MOJIKI_CONTAS_DEMO") == "1":
    from contas_demo import criar_contas_demo
    criar_contas_demo()

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


#confere se o deck existe E e do usuario logado antes de mexer nele
#(deck de outro usuario responde igual a deck inexistente)
def deck_existe(cursor, deck_id: int, usuario_id: int) -> bool:
    cursor.execute("SELECT 1 FROM decks WHERE id = ? AND user_id = ?", (deck_id, usuario_id))
    return cursor.fetchone() is not None


#dependencia de login: le o token do cabecalho e devolve o id do usuario.
#o FastAPI chama isto sozinho em toda rota que tem Depends(usuario_logado).
def usuario_logado(authorization: str | None = Header(None)) -> int:
    token = (authorization or "").removeprefix("Bearer ").strip()
    if token:
        conn = get_connection()
        linha = conn.execute("SELECT user_id, expira_em FROM tokens WHERE token = ?", (token,)).fetchone()
        conn.close()
        if linha and datetime.fromisoformat(linha["expira_em"]) > datetime.now(timezone.utc):
            return linha["user_id"]
    #401 = nao autenticado: o app apaga o token salvo e abre o login
    raise HTTPException(status_code=401, detail="Sua sessão expirou. Entre novamente.")


# =========================
# FLASHCARDS
# =========================

#rota: criar flashcard
@app.post("/flashcards")
def criar_flashcard(card: Flashcard, usuario_id: int = Depends(usuario_logado)):  #usa model (pydantic)
    card.pergunta = obrigatorio(card.pergunta, "Pergunta")
    card.resposta = obrigatorio(card.resposta, "Resposta")

    conn = get_connection()
    cursor = conn.cursor()

    if not deck_existe(cursor, card.deck_id, usuario_id):
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


#rota: listar flashcards (so os dos decks do usuario)
@app.get("/flashcards")
def listar_flashcards(usuario_id: int = Depends(usuario_logado)):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT flashcards.* FROM flashcards
        JOIN decks ON decks.id = flashcards.deck_id
        WHERE decks.user_id = ?
        ORDER BY flashcards.id
    """, (usuario_id,))
    cards = cursor.fetchall()

    conn.close()

    return [dict(card) for card in cards]  #converte pra json


#rota: buscar flashcard por id
@app.get("/flashcards/{id}")
def buscar_flashcard(id: int, usuario_id: int = Depends(usuario_logado)):
    conn = get_connection()
    cursor = conn.cursor()

    #JOIN com decks pra so achar o card se o deck for do usuario
    cursor.execute("""
        SELECT flashcards.* FROM flashcards
        JOIN decks ON decks.id = flashcards.deck_id
        WHERE flashcards.id = ? AND decks.user_id = ?
    """, (id, usuario_id))
    card = cursor.fetchone()

    conn.close()

    if not card:
        return {"erro": "Flashcard não encontrado"}

    return dict(card)


#rota: atualizar flashcard (semana 7 - RF06)
@app.put("/flashcards/{id}")
def atualizar_flashcard(id: int, card: Flashcard, usuario_id: int = Depends(usuario_logado)):
    card.pergunta = obrigatorio(card.pergunta, "Pergunta")
    card.resposta = obrigatorio(card.resposta, "Resposta")

    conn = get_connection()
    cursor = conn.cursor()

    #o deck de destino tambem tem que ser do usuario
    if not deck_existe(cursor, card.deck_id, usuario_id):
        conn.close()
        return {"erro": "Deck não encontrado"}

    #so atualiza se o card estiver num deck do usuario
    cursor.execute(
        """UPDATE flashcards SET pergunta = ?, resposta = ?, deck_id = ?
           WHERE id = ? AND deck_id IN (SELECT id FROM decks WHERE user_id = ?)""",
        (card.pergunta, card.resposta, card.deck_id, id, usuario_id)
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
def deletar_flashcard(id: int, usuario_id: int = Depends(usuario_logado)):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "DELETE FROM flashcards WHERE id = ? AND deck_id IN (SELECT id FROM decks WHERE user_id = ?)",
        (id, usuario_id)
    )

    conn.commit()
    conn.close()

    return {"msg": "Flashcard deletado"}


# =========================
# DECKS
# =========================

#rota: criar deck
@app.post("/decks")
def criar_deck(deck: Deck, usuario_id: int = Depends(usuario_logado)):
    deck.nome = obrigatorio(deck.nome, "Nome do deck")

    conn = get_connection()
    cursor = conn.cursor()

    #o dono e sempre o usuario logado (o user_id do corpo e ignorado)
    cursor.execute(
        "INSERT INTO decks (nome, user_id) VALUES (?, ?)",
        (deck.nome, usuario_id)
    )

    conn.commit()
    novo_id = cursor.lastrowid  #id automatico
    conn.close()

    return {
        "id": novo_id,
        "nome": deck.nome,
        "user_id": usuario_id
    }


#rota: listar decks do usuario (em ordem de criacao)
@app.get("/decks")
def listar_decks(usuario_id: int = Depends(usuario_logado)):
    conn = get_connection()
    cursor = conn.cursor()

    #total_cards: quantidade de flashcards de cada deck (mostrada na Home)
    cursor.execute("""
        SELECT decks.*,
               (SELECT COUNT(*) FROM flashcards WHERE flashcards.deck_id = decks.id) AS total_cards
        FROM decks
        WHERE decks.user_id = ?
        ORDER BY decks.id
    """, (usuario_id,))
    decks = cursor.fetchall()

    conn.close()

    return [dict(deck) for deck in decks]


#rota: buscar deck (com seus flashcards)
@app.get("/decks/{id}")
def buscar_deck(id: int, usuario_id: int = Depends(usuario_logado)):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM decks WHERE id = ? AND user_id = ?", (id, usuario_id))
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
def renomear_deck(id: int, deck: RenomearDeck, usuario_id: int = Depends(usuario_logado)):
    nome = obrigatorio(deck.nome, "Nome do deck")

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("UPDATE decks SET nome = ? WHERE id = ? AND user_id = ?", (nome, id, usuario_id))

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
def deletar_deck(id: int, usuario_id: int = Depends(usuario_logado)):
    conn = get_connection()
    cursor = conn.cursor()

    #deck de outro usuario (ou inexistente): nao apaga nada
    if not deck_existe(cursor, id, usuario_id):
        conn.close()
        return {"msg": "Deck deletado"}

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
async def previa_importacao(arquivo: UploadFile = File(...), usuario_id: int = Depends(usuario_logado)):
    dados = await arquivo.read()
    try:
        return gerar_previa(arquivo.filename or "", dados)
    except ErroImportacao as e:
        raise HTTPException(status_code=400, detail=str(e))


#rota: previa a partir do TEXTO de uma foto ja lida no aparelho (RF12).
#o app faz o OCR la mesmo (ML Kit no celular, Tesseract.js no navegador) e
#manda so o texto -- assim nao precisa do Tesseract instalado no backend.
@app.post("/importar/texto")
def previa_texto(dados: TextoImportado, usuario_id: int = Depends(usuario_logado)):
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
def importar_deck(dados: ImportarDeck, usuario_id: int = Depends(usuario_logado)):
    nome = obrigatorio(dados.nome, "Nome do deck")
    if not dados.cards:
        raise HTTPException(status_code=400, detail="Selecione ao menos um card para importar")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO decks (nome, user_id) VALUES (?, ?)", (nome, usuario_id))
        deck_id = cursor.lastrowid
        criados = _gravar_cards(cursor, deck_id, dados.cards)
        conn.commit()
    except HTTPException:
        conn.rollback()  #algum card vazio: desfaz o deck inteiro
        raise
    finally:
        conn.close()

    return {"id": deck_id, "nome": nome, "user_id": usuario_id, "total_cards": len(criados)}


#rota: adicionar varios cards num deck que ja existe (foto -> cards dentro do deck)
@app.post("/decks/{id}/flashcards/lote")
def adicionar_lote(id: int, dados: LoteCards, usuario_id: int = Depends(usuario_logado)):
    if not dados.cards:
        raise HTTPException(status_code=400, detail="Selecione ao menos um card para importar")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        if not deck_existe(cursor, id, usuario_id):
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
def iniciar_sessao(sessao: IniciarSessao, usuario_id: int = Depends(usuario_logado)):
    if sessao.modo not in MODOS_ESTUDO:
        raise HTTPException(status_code=400, detail="Modo de estudo inválido")

    conn = get_connection()
    cursor = conn.cursor()

    if not deck_existe(cursor, sessao.deck_id, usuario_id):
        conn.close()
        return {"erro": "Deck não encontrado"}

    agora = agora_utc()

    cursor.execute(
        "INSERT INTO study_sessions (user_id, deck_id, acertos, erros, iniciado_em, finalizado_em, modo) VALUES (?, ?, 0, 0, ?, NULL, ?)",
        (usuario_id, sessao.deck_id, agora, sessao.modo)
    )

    conn.commit()
    novo_id = cursor.lastrowid
    conn.close()

    return {
        "id": novo_id,
        "user_id": usuario_id,
        "deck_id": sessao.deck_id,
        "acertos": 0,
        "erros": 0,
        "iniciado_em": agora,
        "finalizado_em": None,
        "modo": sessao.modo
    }


#rota: GET para listar todas as sessoes de estudo
@app.get("/study-sessions")
def listar_sessoes(usuario_id: int = Depends(usuario_logado)):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM study_sessions WHERE user_id = ? ORDER BY id", (usuario_id,))
    sessoes = cursor.fetchall()

    conn.close()

    return [dict(sessao) for sessao in sessoes]


#rota: GET para buscar uma sessao de estudo pelo id
@app.get("/study-sessions/{id}")
def buscar_sessao(id: int, usuario_id: int = Depends(usuario_logado)):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM study_sessions WHERE id = ? AND user_id = ?", (id, usuario_id))
    sessao = cursor.fetchone()

    conn.close()

    if not sessao:
        return {"erro": "Sessão de estudo não encontrada"}

    return dict(sessao)


#rota: registrar a resposta (acertei/errei) de um card estudado dentro de uma sessao
@app.post("/study-sessions/{id}/responder")
def registrar_resposta(id: int, resposta: RegistrarResposta, usuario_id: int = Depends(usuario_logado)):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM study_sessions WHERE id = ? AND user_id = ?", (id, usuario_id))
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
def finalizar_sessao(id: int, usuario_id: int = Depends(usuario_logado)):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM study_sessions WHERE id = ? AND user_id = ?", (id, usuario_id))
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


# =========================
# LOGIN (cadastro, entrar, sair, recuperar senha)
# =========================

#cria um token novo pro usuario e devolve o que o app precisa guardar
def _abrir_sessao(cursor, usuario) -> dict:
    token = auth.gerar_token()
    expira = datetime.now(timezone.utc) + timedelta(days=auth.DIAS_TOKEN)
    cursor.execute("INSERT INTO tokens (token, user_id, expira_em) VALUES (?, ?, ?)",
                   (token, usuario["id"], expira.isoformat()))
    return {"token": token, "id": usuario["id"], "usuario": usuario["usuario"], "email": usuario["email"]}


#rota: criar conta (usuario + e-mail + senha) e ja entrar
@app.post("/auth/cadastro")
def cadastrar(dados: Cadastro):
    usuario = dados.usuario.strip()
    email = dados.email.strip().lower()
    #mesmas regras do app: valida aqui tambem porque a API pode ser chamada sem o app
    erro = auth.erro_usuario(usuario) or auth.erro_email(email) or auth.erro_senha(dados.senha)
    if erro:
        raise HTTPException(status_code=400, detail=erro)

    conn = get_connection()
    cursor = conn.cursor()
    try:
        #COLLATE NOCASE na tabela: "Ana" e "ana" sao o mesmo usuario
        if cursor.execute("SELECT 1 FROM usuarios WHERE usuario = ?", (usuario,)).fetchone():
            raise HTTPException(status_code=400, detail="Esse nome de usuário já está em uso")
        if cursor.execute("SELECT 1 FROM usuarios WHERE email = ?", (email,)).fetchone():
            raise HTTPException(status_code=400, detail="Esse e-mail já está cadastrado")

        senha_hash, salt = auth.gerar_hash(dados.senha)
        cursor.execute(
            "INSERT INTO usuarios (usuario, email, senha_hash, salt, criado_em) VALUES (?, ?, ?, ?, ?)",
            (usuario, email, senha_hash, salt, agora_utc())
        )
        novo = {"id": cursor.lastrowid, "usuario": usuario, "email": email}
        resposta = _abrir_sessao(cursor, novo)
        conn.commit()
        return resposta
    finally:
        conn.close()


#rota: entrar com usuario e senha
@app.post("/auth/login")
def entrar(dados: Login):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        linha = cursor.execute("SELECT * FROM usuarios WHERE usuario = ?", (dados.usuario.strip(),)).fetchone()
        #mesma mensagem pros dois casos: nao revela se o usuario existe
        if not linha or not auth.conferir_senha(dados.senha, linha["senha_hash"], linha["salt"]):
            raise HTTPException(status_code=400, detail="Usuário ou senha incorretos")
        resposta = _abrir_sessao(cursor, linha)
        conn.commit()
        return resposta
    finally:
        conn.close()


#rota: dados do usuario logado (o app usa pra conferir se o token ainda vale)
@app.get("/auth/eu")
def quem_sou_eu(usuario_id: int = Depends(usuario_logado)):
    conn = get_connection()
    linha = conn.execute("SELECT id, usuario, email FROM usuarios WHERE id = ?", (usuario_id,)).fetchone()
    conn.close()
    return dict(linha)


#rota: sair (apaga o token deste aparelho)
@app.post("/auth/sair")
def sair(authorization: str | None = Header(None)):
    token = (authorization or "").removeprefix("Bearer ").strip()
    conn = get_connection()
    conn.execute("DELETE FROM tokens WHERE token = ?", (token,))
    conn.commit()
    conn.close()
    return {"msg": "Você saiu da conta"}


#rota: 1o passo da recuperacao -- gera um codigo de 6 digitos e manda por e-mail
@app.post("/auth/recuperar")
def pedir_recuperacao(dados: PedirRecuperacao):
    email = dados.email.strip().lower()
    erro = auth.erro_email(email)
    if erro:
        raise HTTPException(status_code=400, detail=erro)

    #resposta igual exista ou nao a conta (nao revela quais e-mails estao cadastrados)
    resposta = {"msg": "Se o e-mail estiver cadastrado, você vai receber um código em instantes"}

    conn = get_connection()
    cursor = conn.cursor()
    try:
        linha = cursor.execute("SELECT id, usuario FROM usuarios WHERE email = ?", (email,)).fetchone()
        if not linha:
            return resposta

        codigo = auth.gerar_codigo()
        expira = datetime.now(timezone.utc) + timedelta(minutes=auth.MINUTOS_CODIGO)
        #guarda so o hash do codigo; um pedido novo substitui o anterior
        cursor.execute(
            "UPDATE usuarios SET codigo_hash = ?, codigo_expira_em = ?, codigo_tentativas = 0 WHERE id = ?",
            (auth.hash_codigo(codigo), expira.isoformat(), linha["id"])
        )
        conn.commit()
    finally:
        conn.close()

    try:
        auth.enviar_codigo_por_email(email, linha["usuario"], codigo)
    except Exception as e:  #SMTP fora do ar, senha do SMTP errada...
        print(f"[recuperacao de senha] falha ao enviar e-mail: {e}")
        raise HTTPException(status_code=400, detail="Não foi possível enviar o e-mail agora. Tente mais tarde.")
    return resposta


#rota: 2o passo -- confere o codigo, troca a senha e ja entra na conta
@app.post("/auth/redefinir")
def redefinir_senha(dados: RedefinirSenha):
    email = dados.email.strip().lower()
    erro_codigo = HTTPException(status_code=400, detail="Código inválido ou expirado. Peça um novo código.")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        linha = cursor.execute("SELECT * FROM usuarios WHERE email = ?", (email,)).fetchone()
        if (not linha or not linha["codigo_hash"]
                or linha["codigo_tentativas"] >= auth.TENTATIVAS_CODIGO
                or datetime.fromisoformat(linha["codigo_expira_em"]) < datetime.now(timezone.utc)):
            raise erro_codigo

        if not auth.conferir_codigo(dados.codigo.strip(), linha["codigo_hash"]):
            #conta a tentativa errada (depois de 5 o codigo para de valer)
            cursor.execute("UPDATE usuarios SET codigo_tentativas = codigo_tentativas + 1 WHERE id = ?",
                           (linha["id"],))
            conn.commit()
            raise HTTPException(status_code=400, detail="Código incorreto")

        erro = auth.erro_senha(dados.nova_senha)
        if erro:
            raise HTTPException(status_code=400, detail=erro)

        senha_hash, salt = auth.gerar_hash(dados.nova_senha)
        #troca a senha, apaga o codigo e derruba os logins antigos (outros aparelhos)
        cursor.execute(
            "UPDATE usuarios SET senha_hash = ?, salt = ?, codigo_hash = NULL, codigo_expira_em = NULL, "
            "codigo_tentativas = 0 WHERE id = ?",
            (senha_hash, salt, linha["id"])
        )
        cursor.execute("DELETE FROM tokens WHERE user_id = ?", (linha["id"],))
        resposta = _abrir_sessao(cursor, linha)
        conn.commit()
        return resposta
    finally:
        conn.close()
