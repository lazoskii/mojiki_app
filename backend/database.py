#banco de dados (SQLite): abre a conexao e cria as tabelas (o banco comeca vazio)
import os
import sqlite3

#caminho do banco: sempre ao lado deste arquivo (antes era relativo a pasta
#de onde o servidor era iniciado -- rodando de outra pasta, o backend criava
#um banco novo e vazio e parecia que os decks tinham sumido).
#MOJIKI_DB permite apontar pra outro arquivo (usado nos testes).
CAMINHO_BANCO = os.environ.get(
    "MOJIKI_DB", os.path.join(os.path.dirname(os.path.abspath(__file__)), "flashcards.db")
)


def get_connection():
    conn = sqlite3.connect(CAMINHO_BANCO)
    conn.row_factory = sqlite3.Row  #permite ler as colunas pelo nome: linha["nome"]
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

    #login (13/11): usuario e e-mail sao unicos, sem diferenciar maiuscula de minuscula
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario TEXT UNIQUE COLLATE NOCASE,
        email TEXT UNIQUE COLLATE NOCASE,
        senha_hash TEXT,
        salt TEXT,
        criado_em TEXT,
        codigo_hash TEXT,           -- codigo de recuperacao (so o hash)
        codigo_expira_em TEXT,
        codigo_tentativas INTEGER DEFAULT 0
    )
    """)

    #17/11: tipo de conta ("aluno" ou "professor") e nivel JLPT do aluno (N5..N1).
    #Por enquanto so identificam a conta; as permissoes de professor (publicar
    #decks para os alunos) ficam para o futuro -- ver docs/requisitos.md (RF14).
    colunas = [c["name"] for c in cursor.execute("PRAGMA table_info(usuarios)")]
    if "tipo" not in colunas:
        cursor.execute("ALTER TABLE usuarios ADD COLUMN tipo TEXT DEFAULT 'aluno'")
    if "nivel" not in colunas:
        cursor.execute("ALTER TABLE usuarios ADD COLUMN nivel TEXT")

    #tokens de login: um por aparelho em que o usuario entrou
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS tokens (
        token TEXT PRIMARY KEY,
        user_id INTEGER,
        expira_em TEXT
    )
    """)

    conn.commit()
    conn.close()


#o deck de teste fixo (semana 2) foi removido em 13/11: o banco comeca
#vazio e os decks prontos ficam em decks_para_importar/ (fora do banco),
#pra importar pelo app quando quiser.
