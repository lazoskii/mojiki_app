# Mojiki

## Diagnóstico do projeto

O Mojiki é um aplicativo de flashcards voltado para estudantes, com backend em **FastAPI + SQLite** e frontend em **Flutter** (7 telas). O app já tem 9 endpoints ativos e CRUD real de decks e flashcards, mas nunca teve um requisito escrito nem um caso de teste documentado.

Este diagnóstico parte disso: para cada problema encontrado, definimos o requisito que falta, o teste que expõe a falha e a correção necessária. Foram selecionadas 4 frentes prioritárias, e o restante dos pontos de melhoria fica registrado como backlog.

## O que já funciona

- **CRUD real de decks e flashcards**, persistido em SQLite — não é mais dado mockado.
- **Navegação completa** entre as 7 telas via go_router, incluindo onboarding só na primeira vez.
- **Progresso local** — cards estudados e sequência de dias já são acompanhados de verdade.
- **Menu lateral** unificando o acesso a Decks, Sessão de Estudo e Progresso.

## Pontos de melhoria

| Frente | Item | Descrição |
|---|---|---|
| Robustez | Tela trava no "carregando" | Se a API cair ou a rede falhar, a tela fica presa no spinner — nenhuma chamada tem tratamento de erro. |
| Robustez | Exclusão sem confirmação | Apagar um deck ou flashcard é instantâneo, sem diálogo de confirmação nem forma de desfazer. |
| CRUD incompleto | Editar flashcard não existe | O backend já tem `PUT /flashcards/{id}` pronto, mas o app nunca chama — dá pra criar e excluir, não corrigir. |
| CRUD incompleto | Deck não tem edição | Não existe endpoint de renomear deck — só criar e excluir. |
| Funcionalidade morta | Modos de estudo são só visual | Os cards de Sessão Rápida / Diária / Intensiva não fazem nada ao tocar — puramente decorativos. |
| Funcionalidade morta | StudySession nunca é usada | O model com `acertos`/`erros` existe em `models.py`, mas nenhuma rota grava ou lê esses dados. |
| Outras menores | Sem busca | Não há como filtrar decks ou cards por nome quando a lista cresce. |
| Outras menores | user_id sempre fixo | Todo deck é criado com `user_id = 1` — não existem usuários reais ainda. |

## Quebrando em tasks

A numeração dos blocos segue a ordem de prioridade da apresentação; os blocos 4 a 7 cobrem o restante dos pontos de melhoria.

### Bloco 1 — Autoavaliação real (Acertei / Errei)

- [ ] Adicionar endpoint para registrar a resposta (acerto/erro) de um card estudado — **M**
- [ ] Persistir o resultado usando o model `StudySession` já existente — **M**
- [ ] Adicionar botões "Acertei" / "Errei" na tela de estudo (Flutter) — **M**
- [ ] Chamar a API ao tocar em Acertei/Errei — **P**
- [ ] Testar o fluxo completo: marcar resposta → salvar → conferir no banco — **P**

### Bloco 2 — Documento de requisitos

- [ ] Levantar as regras que o app deveria seguir (ex.: não criar deck sem nome) — **M**
- [ ] Escrever os 8 requisitos em formato claro — **P**
- [ ] Revisar os requisitos com o grupo/professor — **P**

### Bloco 3 — Casos de teste ligados aos requisitos

- [ ] Criar um caso de teste por requisito (passo a passo + resultado esperado) — **M**
- [ ] Executar os testes manualmente no app atual — **M**
- [ ] Registrar os defeitos encontrados (ex.: deck com nome vazio aceito, exclusão sem confirmação) — **P**
- [ ] Priorizar quais defeitos corrigir primeiro — **P**

### Bloco 4 — Robustez (tratamento de erro e confirmação)

- [ ] Adicionar tratamento de erro nas chamadas de API, em vez de travar no "carregando" — **M**
- [ ] Mostrar mensagem de erro/retry quando a API falhar ou a rede cair — **M**
- [ ] Adicionar diálogo de confirmação antes de excluir um deck — **P**
- [ ] Adicionar diálogo de confirmação antes de excluir um flashcard — **P**

### Bloco 5 — CRUD incompleto (edição)

- [ ] Ligar a tela de edição de flashcard ao endpoint `PUT /flashcards/{id}` já existente — **M**
- [ ] Criar endpoint de edição (renomear) de deck no backend — **M**
- [ ] Adicionar opção de editar deck na interface — **P**
- [ ] Testar a edição de flashcard e de deck — **P**

### Bloco 6 — Funcionalidade morta (modos de estudo)

- [ ] Definir o comportamento esperado de cada modo (Rápida / Diária / Intensiva) — **P**
- [ ] Implementar a ação dos cards de modo de estudo — **G**
- [ ] Ligar os modos de estudo ao registro de progresso (`StudySession`) — **M**

### Bloco 7 — Outras melhorias menores

- [ ] Adicionar campo de busca para decks — **M**
- [ ] Adicionar busca de cards dentro de um deck — **M**
- [ ] Registrar o `user_id` fixo como pendência de backlog, para quando existir autenticação real — **P**

## Tamanho das tasks

- **P — Pequena:** pode ser concluída em algumas horas.
- **M — Média:** pode levar aproximadamente um dia.
- **G — Grande:** pode levar de dois a três dias e talvez precise ser dividida.

As estimativas servem para ajudar na priorização e podem ser revisadas durante o planejamento.

## Fora do escopo neste momento

- Autenticação real de usuários (login, múltiplas contas).
- Notificações ou lembretes automáticos.
- Sincronização entre dispositivos.
- Testes automatizados (por enquanto os testes são executados manualmente, a partir dos casos de teste do Bloco 3).
