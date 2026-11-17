#autenticacao: senha com hash, token de login e codigo de recuperacao por e-mail.
#so usa a biblioteca padrao do Python (hashlib, secrets, smtplib).
import hashlib
import hmac
import os
import re
import secrets
import smtplib
from email.message import EmailMessage

#validade do token de login e do codigo de recuperacao
DIAS_TOKEN = 30
MINUTOS_CODIGO = 15
TENTATIVAS_CODIGO = 5  #depois disso o codigo e invalidado (evita chutar os 6 digitos)


#senha nunca e guardada em texto puro: guarda o hash PBKDF2 + um salt aleatorio
def gerar_hash(senha: str, salt: str | None = None) -> tuple[str, str]:
    salt = salt or secrets.token_hex(16)  #salt diferente pra cada usuario
    hash_ = hashlib.pbkdf2_hmac("sha256", senha.encode(), salt.encode(), 200_000).hex()
    return hash_, salt


def conferir_senha(senha: str, hash_salvo: str, salt: str) -> bool:
    hash_, _ = gerar_hash(senha, salt)
    return hmac.compare_digest(hash_, hash_salvo)  #comparacao em tempo constante


#token aleatorio que o app manda em toda requisicao (cabecalho Authorization)
def gerar_token() -> str:
    return secrets.token_urlsafe(32)


#codigo de 6 digitos para recuperar a senha
def gerar_codigo() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_codigo(codigo: str) -> str:
    return hashlib.sha256(codigo.encode()).hexdigest()


def conferir_codigo(codigo: str, hash_salvo: str) -> bool:
    return hmac.compare_digest(hash_codigo(codigo), hash_salvo)


# ---------- regras de validacao (as mesmas do app, ver validacao_login.dart) ----------

def erro_senha(senha: str) -> str | None:
    """Senha: minimo 8 caracteres, com pelo menos um numero e uma letra maiuscula."""
    if len(senha) < 8:
        return "A senha precisa ter pelo menos 8 caracteres"
    if len(senha) > 128:  #senha enorme deixaria o PBKDF2 lento de proposito
        return "A senha pode ter no máximo 128 caracteres"
    if not re.search(r"[0-9]", senha):
        return "A senha precisa ter pelo menos um número"
    if not any(c.isupper() for c in senha):
        return "A senha precisa ter pelo menos uma letra maiúscula"
    return None


def erro_usuario(usuario: str) -> str | None:
    #3 a 30 caracteres: letras, numeros, ponto e sublinhado (sem espaco)
    if not re.fullmatch(r"[A-Za-z0-9._]{3,30}", usuario):
        return "O usuário deve ter de 3 a 30 caracteres: letras, números, ponto ou _"
    return None


def erro_email(email: str) -> str | None:
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        return "Digite um e-mail válido"
    return None


# ---------- envio do e-mail de recuperacao ----------

def enviar_codigo_por_email(email: str, usuario: str, codigo: str) -> None:
    """Envia o codigo por SMTP. Sem SMTP configurado, so escreve no log do servidor."""
    host = os.environ.get("SMTP_HOST")
    if not host:
        #modo desenvolvimento: o codigo aparece no terminal do uvicorn (ou no log do Render)
        print(f"[recuperacao de senha] usuario={usuario} email={email} codigo={codigo}")
        return

    msg = EmailMessage()
    msg["Subject"] = "Mojiki - código para redefinir a senha"
    msg["From"] = os.environ.get("SMTP_REMETENTE", os.environ.get("SMTP_USUARIO", ""))
    msg["To"] = email
    msg.set_content(
        f"Olá, {usuario}!\n\n"
        f"Seu código para redefinir a senha do Mojiki é: {codigo}\n"
        f"Ele vale por {MINUTOS_CODIGO} minutos.\n\n"
        "Se não foi você que pediu, ignore este e-mail."
    )
    porta = int(os.environ.get("SMTP_PORTA", "587"))
    with smtplib.SMTP(host, porta, timeout=15) as smtp:
        smtp.starttls()  #conexao criptografada
        smtp.login(os.environ.get("SMTP_USUARIO", ""), os.environ.get("SMTP_SENHA", ""))
        smtp.send_message(msg)
