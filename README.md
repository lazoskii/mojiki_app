# Mojiki

## Diagnóstico do projeto

O Mojiki é um aplicativo de flashcards voltado para estudantes, com backend em **FastAPI + SQLite** e frontend em **Flutter** (7 telas). O app já tem 9 endpoints ativos e CRUD real de decks e flashcards, mas nunca teve um requisito escrito nem um caso de teste documentado.

Este diagnóstico parte disso: para cada problema encontrado, definimos o requisito que falta, o teste que expõe a falha e a correção necessária. Foram selecionadas 4 frentes prioritárias, e o restante dos pontos de melhoria fica registrado como backlog.

## O que já funciona

- **CRUD real de decks e flashcards**, persistido em SQLite — não é mais dado mockado.
- **Navegação completa** entre as 7 telas via go_router, incluindo onboarding só na primeira vez.
- **Progresso local** — cards estudados e sequência de dias já são acompanhados de verdade.
- **Menu lateral** unificando o acesso a Decks, Sessão de Estudo e Progresso.

### Entregue durante o cronograma (Blocos 1 a 7)

- **Autoavaliação** — botões Acertei / Errei gravados na `StudySession`, com tela de resultado (% de acerto) no fim da sessão.
- **Robustez** — toda chamada de API trata falha de rede (tela de erro com "Tentar novamente") e excluir deck/flashcard pede confirmação.
- **Validação** — deck sem nome e flashcard sem pergunta/resposta são recusados no app e no backend (erro 400).
- **Edição** — editar pergunta/resposta de um flashcard e renomear deck.
- **Modos de estudo** — Sessão Rápida, Prática Diária e Sessão Intensiva com cronômetro, cards embaralhados e o modo gravado na sessão.
- **Busca** — de decks na Home e de cards dentro de um deck (ignora maiúsculas e acentos).
- **Extras** — XP, nível e conquistas na tela de Progresso; "Enviar feedback" no menu; tema visual único (`flutter_frontend/lib/theme/app_theme.dart`).

## Como rodar

**Backend** (FastAPI + SQLite, porta 8000):

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

O banco `flashcards.db` e o deck de teste são criados automaticamente na primeira execução.

**App** (Flutter):

```bash
cd flutter_frontend
flutter pub get
flutter run -d chrome   # ou -d edge, ou um emulador Android
```

**Testes automatizados** (não precisam do backend rodando):

```bash
cd flutter_frontend
flutter test
```

## Pontos de melhoria

Diagnóstico feito no início do projeto (25/08). A coluna **Situação** mostra como cada ponto ficou na entrega.

| Frente | Item | Descrição | Situação |
|---|---|---|---|
| Robustez | Tela trava no "carregando" | Se a API cair ou a rede falhar, a tela fica presa no spinner — nenhuma chamada tem tratamento de erro. | Resolvido (Bloco 4) |
| Robustez | Exclusão sem confirmação | Apagar um deck ou flashcard é instantâneo, sem diálogo de confirmação nem forma de desfazer. | Resolvido (Bloco 4) |
| CRUD incompleto | Editar flashcard não existe | O backend já tem `PUT /flashcards/{id}` pronto, mas o app nunca chama — dá pra criar e excluir, não corrigir. | Resolvido (Bloco 5) |
| CRUD incompleto | Deck não tem edição | Não existe endpoint de renomear deck — só criar e excluir. | Resolvido (Bloco 5) |
| Funcionalidade morta | Modos de estudo são só visual | Os cards de Sessão Rápida / Diária / Intensiva não fazem nada ao tocar — puramente decorativos. | Resolvido (Bloco 6) |
| Funcionalidade morta | StudySession nunca é usada | O model com `acertos`/`erros` existe em `models.py`, mas nenhuma rota grava ou lê esses dados. | Resolvido (Blocos 1 e 6) |
| Outras menores | Sem busca | Não há como filtrar decks ou cards por nome quando a lista cresce. | Resolvido (Bloco 7) |
| Outras menores | user_id sempre fixo | Todo deck é criado com `user_id = 1` — não existem usuários reais ainda. | Backlog (ver abaixo) |

## Quebrando em tasks

A numeração dos blocos segue a ordem de prioridade da apresentação; os blocos 4 a 7 cobrem o restante dos pontos de melhoria.

### Bloco 1 — Autoavaliação real (Acertei / Errei)

- [x] Adicionar endpoint para registrar a resposta (acerto/erro) de um card estudado — **M**
- [x] Persistir o resultado usando o model `StudySession` já existente — **M**
- [x] Adicionar botões "Acertei" / "Errei" na tela de estudo (Flutter) — **M**
- [x] Chamar a API ao tocar em Acertei/Errei — **P**
- [x] Testar o fluxo completo: marcar resposta → salvar → conferir no banco — **P**

### Bloco 2 — Documento de requisitos

- [x] Levantar as regras que o app deveria seguir (ex.: não criar deck sem nome) — **M**
- [x] Escrever os 8 requisitos em formato claro — **P** → [docs/requisitos.md](docs/requisitos.md)
- [ ] Revisar os requisitos com o grupo/professor — **P**

### Bloco 3 — Casos de teste ligados aos requisitos

- [x] Criar um caso de teste por requisito (passo a passo + resultado esperado) — **M** → [docs/casos_de_teste.md](docs/casos_de_teste.md)
- [x] Executar os testes manualmente no app atual — **M**
- [x] Registrar os defeitos encontrados (ex.: deck com nome vazio aceito, exclusão sem confirmação) — **P**
- [x] Priorizar quais defeitos corrigir primeiro — **P**

### Bloco 4 — Robustez (tratamento de erro e confirmação)

- [x] Adicionar tratamento de erro nas chamadas de API, em vez de travar no "carregando" — **M**
- [x] Mostrar mensagem de erro/retry quando a API falhar ou a rede cair — **M**
- [x] Adicionar diálogo de confirmação antes de excluir um deck — **P**
- [x] Adicionar diálogo de confirmação antes de excluir um flashcard — **P**

### Bloco 5 — CRUD incompleto (edição)

- [x] Ligar a tela de edição de flashcard ao endpoint `PUT /flashcards/{id}` já existente — **M**
- [x] Criar endpoint de edição (renomear) de deck no backend — **M**
- [x] Adicionar opção de editar deck na interface — **P**
- [x] Testar a edição de flashcard e de deck — **P** → testes automatizados em [flutter_frontend/test/edicao_e_busca_test.dart](flutter_frontend/test/edicao_e_busca_test.dart)

### Bloco 6 — Funcionalidade morta (modos de estudo)

- [x] Definir o comportamento esperado de cada modo (Rápida / Diária / Intensiva) — **P**
- [x] Implementar a ação dos cards de modo de estudo — **G**
- [x] Ligar os modos de estudo ao registro de progresso (`StudySession`) — **M**

### Bloco 7 — Outras melhorias menores

- [x] Adicionar campo de busca para decks — **M**
- [x] Adicionar busca de cards dentro de um deck — **M**
- [x] Registrar o `user_id` fixo como pendência de backlog, para quando existir autenticação real — **P** → seção [Backlog](#backlog)

## Tamanho das tasks

- **P — Pequena:** pode ser concluída em algumas horas.
- **M — Média:** pode levar aproximadamente um dia.
- **G — Grande:** pode levar de dois a três dias e talvez precise ser dividida.

As estimativas servem para ajudar na priorização e podem ser revisadas durante o planejamento.

## Cronograma do projeto

Estimativa a partir de hoje (25/08) até a entrega em 17/11 — 12 semanas ao todo. O peso de cada bloco em semanas segue a quantidade e o tamanho (P/M/G) das tasks dele.

| Semana | Período | Bloco | Foco |
|---|---|---|---|
| 1 | 25/08 – 31/08 | Bloco 1 | Autoavaliação real — endpoint + persistência (StudySession) |
| 2 | 01/09 – 07/09 | Bloco 1 | Autoavaliação real — botões no Flutter, integração e testes |
| 3 | 08/09 – 14/09 | Bloco 2 | Documento de requisitos e tela de progresso com porcentagem |
| 4 | 15/09 – 21/09 | Bloco 3 | Casos de teste ligados aos requisitos |
| 5 | 22/09 – 28/09 | Bloco 4 | Robustez — tratamento de erro nas chamadas de API |
| 6 | 29/09 – 05/10 | Bloco 4 | Robustez — confirmação antes de excluir |
| 7 | 06/10 – 12/10 | Bloco 5 | CRUD incompleto — edição de flashcard |
| 8 | 13/10 – 19/10 | Bloco 5 | CRUD incompleto — edição de deck |
| 9 | 20/10 – 26/10 | Bloco 6 | Funcionalidade morta — definir e implementar modos de estudo |
| 10 | 27/10 – 02/11 | Bloco 6 | Funcionalidade morta — ligar modos de estudo ao progresso |
| 11 | 03/11 – 09/11 | Bloco 7 | Outras menores — busca de decks e cards |
| 12 | 10/11 – 16/11 | Bloco 7 | Outras menores — backlog de user_id e ajustes finais |
| — | 17/11 | Entrega | Revisão final e entrega do projeto |

Essa distribuição é uma estimativa e pode ser ajustada durante o andamento — os blocos 1 a 3 são prioridade e não devem atrasar; os blocos 6 e 7 têm mais folga para absorver imprevistos.

## Backlog

Pendências registradas para depois da entrega:

- **`user_id` fixo** — o app ainda não tem login, então todo deck e toda sessão de estudo são gravados com `user_id = 1`. No app esse valor está centralizado na constante `usuarioFixoId` (`flutter_frontend/lib/services/api_service.dart`); quando existir autenticação real, basta trocar a constante pelo id do usuário logado e fazer o backend filtrar `GET /decks` por usuário.
- **Progresso só no aparelho** — XP, nível, conquistas e sequência de dias ficam no `SharedPreferences` (local). Com usuários reais, faz sentido levar isso para o backend.
- **`session_result_screen.dart`** — tela de resultado em página cheia que ficou sem uso depois da junção com a janela `session_results_dialog.dart`; pode ser removida ou reaproveitada.

## Fora do escopo neste momento

- Autenticação real de usuários (login, múltiplas contas).
- Notificações ou lembretes automáticos.
- Sincronização entre dispositivos.
- Repetição espaçada (agendar quando cada card volta, como no Anki).

Sobre testes: os casos de teste do Bloco 3 ([docs/casos_de_teste.md](docs/casos_de_teste.md)) são o roteiro manual. Além deles, `flutter_frontend/test/` tem testes automatizados de widget cobrindo autoavaliação, edição, validação e busca.
