from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class User(BaseModel):
    id: Optional[int] = None
    nome: str
    email: str
    senha: str

class Deck(BaseModel):
    id: Optional[int] = None
    nome: str
    user_id: int

class Flashcard(BaseModel):
    id: Optional[int] = None  #deu erro 422 quando fui testar o fastapi pq geralmente a id o banco cria depois, entao é bom deixar ela como optional
    pergunta: str
    resposta: str
    deck_id: int

class StudySession(BaseModel):
    id: Optional[int] = None
    user_id: int
    deck_id: int
    acertos: int
    erros: int
    iniciado_em: datetime = Field(default_factory=datetime.utcnow)
    finalizado_em: Optional[datetime] = None

#DADOS CRIADOS PELO USUARIO NAO DEVEM >EXIGIR< ID

    

