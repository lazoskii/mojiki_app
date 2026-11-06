import sqlite3

def get_connection():
    conn = sqlite3.connect("flashcards.db")
    conn.row_factory = sqlite3.Row
    return conn


def create_tables():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS decks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT,
        user_id INTEGER
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pergunta TEXT,
        resposta TEXT,
        deck_id INTEGER
    )
    """)


    #mudancas semana 1

    #guarda o resultado da autoavaliacao (acertos/erros) de uma sessao de estudo
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        deck_id INTEGER,
        acertos INTEGER DEFAULT 0,
        erros INTEGER DEFAULT 0,
        iniciado_em TEXT,
        finalizado_em TEXT
    )
    """)

    #semana 10: modo de estudo da sessao (rapida/diaria/intensiva, ou NULL
    #quando o deck e aberto direto da Home). ALTER TABLE pra nao precisar
    #apagar o flashcards.db de quem ja tem a tabela criada.
    colunas = [c["name"] for c in cursor.execute("PRAGMA table_info(study_sessions)")]
    if "modo" not in colunas:
        cursor.execute("ALTER TABLE study_sessions ADD COLUMN modo TEXT")

    #guarda o feedback enviado pelos usuarios (link "Enviar feedback" no menu)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS feedbacks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mensagem TEXT,
        criado_em TEXT
    )
    """)

    conn.commit()
    conn.close()


#mudancas semana 2

# nome fixo do deck de teste. Serve pra sempre existir um deck pronto pra
# testar o app (autoavaliacao, edicao, etc.), em qualquer maquina que rodar
# o backend -- nao depende do arquivo flashcards.db ter sido copiado junto.
DECK_TESTE_NOME = "🧪 Deck de Teste (fixo)"

#roda toda vez que o backend sobe (ver main.py). So insere se ainda nao
#existir, entao e seguro chamar toda vez sem duplicar.
def seed_dados_teste():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT id FROM decks WHERE nome = ?", (DECK_TESTE_NOME,))
    ja_existe = cursor.fetchone()

    if not ja_existe:
        cursor.execute(
            "INSERT INTO decks (nome, user_id) VALUES (?, ?)",
            (DECK_TESTE_NOME, 1)
        )
        deck_id = cursor.lastrowid

        cursor.executemany(
            "INSERT INTO flashcards (pergunta, resposta, deck_id) VALUES (?, ?, ?)",
            [
                ("Qual comando sobe o backend com reload automático?", "uvicorn main:app --reload", deck_id),
                ("Qual verbo HTTP edita um flashcard existente?", "PUT", deck_id),
                ("Onde o Mojiki guarda decks e flashcards?", "Num banco SQLite (flashcards.db)", deck_id),
            ]
        )
        conn.commit()

    conn.close()