#contas fixas de demonstracao: 1 professor + 1 aluno por nivel do JLPT (N5 a N1),
#cada aluno com um deck de vocabulario do seu nivel.
#
#  - criar no banco local:   venv\Scripts\python contas_demo.py
#  - ou automatico ao subir o servidor com MOJIKI_CONTAS_DEMO=1 (o rodar_local.bat faz isso)
#
#Pode rodar quantas vezes quiser: conta que ja existe nao e mexida.
#Criar conta pelo app continua funcionando normalmente.
#As listas de vocabulario seguem as listas mais usadas para cada nivel; o
#JLPT nao publica lista oficial de palavras.

from auth import gerar_hash
from database import create_tables, get_connection

SENHA_DEMO = "Mojiki2026"  #a mesma para todas (8+ caracteres, numero e maiuscula)

VOCABULARIO = {
    "N5": [
        ("水 (みず)", "água"), ("火 (ひ)", "fogo"), ("山 (やま)", "montanha"), ("川 (かわ)", "rio"),
        ("人 (ひと)", "pessoa"), ("学校 (がっこう)", "escola"), ("先生 (せんせい)", "professor"),
        ("学生 (がくせい)", "estudante"), ("友達 (ともだち)", "amigo"), ("食べる (たべる)", "comer"),
        ("飲む (のむ)", "beber"), ("見る (みる)", "ver"), ("行く (いく)", "ir"), ("来る (くる)", "vir"),
        ("大きい (おおきい)", "grande"), ("小さい (ちいさい)", "pequeno"), ("今日 (きょう)", "hoje"),
        ("明日 (あした)", "amanhã"), ("本 (ほん)", "livro"), ("電車 (でんしゃ)", "trem"),
    ],
    "N4": [
        ("経験 (けいけん)", "experiência"), ("準備 (じゅんび)", "preparação"),
        ("説明 (せつめい)", "explicação"), ("届ける (とどける)", "entregar"),
        ("集める (あつめる)", "juntar, colecionar"), ("急ぐ (いそぐ)", "apressar-se"),
        ("決める (きめる)", "decidir"), ("壊れる (こわれる)", "quebrar (sozinho)"),
        ("安心 (あんしん)", "alívio, tranquilidade"), ("危ない (あぶない)", "perigoso"),
        ("珍しい (めずらしい)", "raro, incomum"), ("優しい (やさしい)", "gentil, carinhoso"),
        ("会議 (かいぎ)", "reunião"), ("季節 (きせつ)", "estação do ano"), ("空港 (くうこう)", "aeroporto"),
        ("趣味 (しゅみ)", "hobby, passatempo"), ("約束 (やくそく)", "promessa, compromisso"),
        ("文化 (ぶんか)", "cultura"), ("運転 (うんてん)", "dirigir (um veículo)"), ("世界 (せかい)", "mundo"),
    ],
    "N3": [
        ("影響 (えいきょう)", "influência"), ("状況 (じょうきょう)", "situação"),
        ("現在 (げんざい)", "atualmente, o presente"), ("努力 (どりょく)", "esforço"),
        ("確認 (かくにん)", "confirmação"), ("比べる (くらべる)", "comparar"),
        ("増える (ふえる)", "aumentar"), ("減る (へる)", "diminuir"),
        ("認める (みとめる)", "reconhecer, admitir"), ("迷う (まよう)", "ficar indeciso, perder-se"),
        ("責任 (せきにん)", "responsabilidade"), ("環境 (かんきょう)", "meio ambiente"),
        ("機会 (きかい)", "oportunidade"), ("意識 (いしき)", "consciência"),
        ("複雑 (ふくざつ)", "complicado"), ("正確 (せいかく)", "exato, preciso"),
        ("当然 (とうぜん)", "natural, óbvio"), ("次第に (しだいに)", "gradualmente"),
        ("募集 (ぼしゅう)", "recrutamento, inscrições"), ("普段 (ふだん)", "normalmente, no dia a dia"),
    ],
    "N2": [
        ("維持 (いじ)", "manutenção"), ("改善 (かいぜん)", "melhoria"), ("傾向 (けいこう)", "tendência"),
        ("把握 (はあく)", "compreensão (de uma situação)"), ("妥協 (だきょう)", "concessão, acordo"),
        ("促す (うながす)", "incentivar, estimular"), ("補う (おぎなう)", "compensar, suprir"),
        ("携わる (たずさわる)", "participar, envolver-se"), ("怠る (おこたる)", "negligenciar"),
        ("著しい (いちじるしい)", "notável, marcante"), ("曖昧 (あいまい)", "ambíguo, vago"),
        ("柔軟 (じゅうなん)", "flexível"), ("貢献 (こうけん)", "contribuição"),
        ("交渉 (こうしょう)", "negociação"), ("削減 (さくげん)", "redução, corte"),
        ("需要 (じゅよう)", "demanda"), ("措置 (そち)", "medida, providência"),
        ("前提 (ぜんてい)", "premissa, pressuposto"), ("見込み (みこみ)", "expectativa, previsão"),
        ("徐々に (じょじょに)", "aos poucos"),
    ],
    "N1": [
        ("懸念 (けねん)", "preocupação, apreensão"), ("是正 (ぜせい)", "correção, retificação"),
        ("顕著 (けんちょ)", "evidente, notável"), ("漠然 (ばくぜん)", "vago, impreciso"),
        ("踏襲 (とうしゅう)", "seguir (um precedente)"), ("逸脱 (いつだつ)", "desvio"),
        ("斡旋 (あっせん)", "intermediação"), ("拮抗 (きっこう)", "rivalidade equilibrada"),
        ("網羅 (もうら)", "abranger tudo"), ("覆す (くつがえす)", "derrubar, reverter"),
        ("培う (つちかう)", "cultivar, desenvolver"), ("賄う (まかなう)", "custear, suprir"),
        ("戒める (いましめる)", "advertir"), ("潔い (いさぎよい)", "digno, resoluto"),
        ("目論む (もくろむ)", "planejar, tramar"), ("頑な (かたくな)", "teimoso, obstinado"),
        ("安易 (あんい)", "simplista, fácil demais"), ("余儀ない (よぎない)", "inevitável"),
        ("一環 (いっかん)", "parte (de um todo)"), ("抜本的 (ばっぽんてき)", "radical, fundamental"),
    ],
}

#(usuario, e-mail, tipo, nivel)
CONTAS = [("professor", "professor@mojiki.demo", "professor", None)] + [
    (f"aluno.{n.lower()}", f"aluno.{n.lower()}@mojiki.demo", "aluno", n) for n in VOCABULARIO
]


def criar_contas_demo() -> list[str]:
    """Cria as contas que ainda nao existem e devolve os nomes criados."""
    create_tables()
    conn = get_connection()
    cursor = conn.cursor()
    criadas = []
    for usuario, email, tipo, nivel in CONTAS:
        if cursor.execute("SELECT 1 FROM usuarios WHERE usuario = ?", (usuario,)).fetchone():
            continue
        senha_hash, salt = gerar_hash(SENHA_DEMO)
        cursor.execute(
            "INSERT INTO usuarios (usuario, email, senha_hash, salt, criado_em, tipo, nivel) "
            "VALUES (?, ?, ?, ?, datetime('now'), ?, ?)",
            (usuario, email, senha_hash, salt, tipo, nivel))
        user_id = cursor.lastrowid
        if nivel:
            cursor.execute("INSERT INTO decks (nome, user_id) VALUES (?, ?)",
                           (f"Vocabulário JLPT {nivel}", user_id))
            deck_id = cursor.lastrowid
            cursor.executemany(
                "INSERT INTO flashcards (pergunta, resposta, deck_id) VALUES (?, ?, ?)",
                [(p, r, deck_id) for p, r in VOCABULARIO[nivel]])
        criadas.append(usuario)
    conn.commit()
    conn.close()
    return criadas


if __name__ == "__main__":
    criadas = criar_contas_demo()
    print("Contas criadas:", ", ".join(criadas) if criadas else "nenhuma (já existiam)")
    print(f"Senha de todas: {SENHA_DEMO}")
