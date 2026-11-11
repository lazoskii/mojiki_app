# Casos de Teste — Mojiki

Semana 4 do cronograma (ver [README.md](../README.md), Bloco 3). Um caso de teste por requisito de [requisitos.md](requisitos.md), executado manualmente contra o estado atual do app (backend em `backend/main.py`, frontend em `flutter_frontend/lib/`). Resultado obtido confirmado por leitura do código correspondente a cada fluxo.

## CT01 — Criar deck com nome vazio (RF01)

- **Pré-condição:** app aberto na tela Home, backend rodando.
- **Passos:** 1) Tocar em "novo deck". 2) Deixar o campo de nome vazio. 3) Tocar em "Criar".
- **Resultado esperado:** o app rejeita a criação e mostra um aviso pedindo o nome.
- **Resultado obtido:** o backend (`POST /decks`) não valida `nome`, aceita string vazia e cria o registro. O frontend bloqueia string totalmente vazia no clique, mas um nome só com espaços passa (`" "`) e é aceito pelos dois lados.
- **Status:** **Falhou.**
- **Defeito:** deck com nome em branco (só espaços) é criado e aparece na lista sem identificação útil.
- **Reteste (Bloco 7, ajustes finais):** o app mostra "Digite um nome para o deck." e não chama a API; o backend recusa nome vazio/só espaços com 400 (`POST /decks` e `PUT /decks/{id}`). Coberto por teste automatizado. **Passou.**

## CT02 — Criar flashcard com pergunta ou resposta vazia (RF02)

- **Pré-condição:** dentro de um deck existente.
- **Passos:** 1) Tocar em "novo flashcard". 2) Preencher só a pergunta, deixando a resposta vazia. 3) Confirmar.
- **Resultado esperado:** criação bloqueada com aviso.
- **Resultado obtido:** o frontend (`study_screen.dart`) já exige os dois campos não vazios antes de chamar a API. Mas o backend (`POST /flashcards`) não valida nada — um `curl` ou outro cliente pode gravar pergunta/resposta vazia direto.
- **Status:** **Falhou (parcialmente)** — protegido só no cliente, não no servidor.
- **Defeito:** validação ausente no backend; qualquer chamada direta à API contorna a regra.
- **Reteste (Bloco 7, ajustes finais):** `POST /flashcards` e `PUT /flashcards/{id}` recusam pergunta ou resposta vazias com 400 (conferido chamando as rotas); o app avisa "Preencha a pergunta e a resposta.". **Passou.**

## CT03 — API fora do ar ao abrir a Home (RF03)

- **Pré-condição:** backend desligado.
- **Passos:** 1) Abrir o app. 2) Aguardar o carregamento da lista de decks.
- **Resultado esperado:** tela sai do spinner e mostra mensagem de erro com opção de tentar novamente.
- **Resultado obtido:** `ApiService.listarDecks()` não tem try/catch; a exceção de conexão sobe sem tratamento e a tela de Home fica presa no `CircularProgressIndicator` indefinidamente.
- **Status:** **Falhou.**
- **Defeito:** nenhuma chamada em `ApiService` fora da sessão de estudo trata falha de rede; Home, criação e exclusão de deck/flashcard ficam vulneráveis ao mesmo travamento.
- **Reteste (Bloco 4):** toda chamada do `ApiService` tem timeout de 10s e trata falha de rede; Home, Sessão de Estudo, estudo de um deck e Progresso mostram a tela de erro com "Tentar novamente" em vez de travar. **Passou.**

## CT04 — Excluir deck sem confirmação (RF04)

- **Pré-condição:** existe ao menos um deck na lista.
- **Passos:** 1) Tocar no ícone de lixeira de um deck.
- **Resultado esperado:** diálogo de confirmação aparece antes de excluir.
- **Resultado obtido:** `_deletarDeck` em `home_screen.dart` chama `ApiService.deletarDeck(id)` direto no `onTap`, sem diálogo. O deck e todos os seus flashcards são apagados imediatamente, sem confirmação nem forma de desfazer.
- **Status:** **Falhou.**
- **Defeito:** exclusão de deck é irreversível e sem aviso — risco de perda de dados por toque acidental.
- **Reteste (Bloco 4):** a lixeira abre "Excluir deck?" avisando que os flashcards também serão apagados; Cancelar não chama a API. **Passou.**

## CT05 — Excluir flashcard sem confirmação (RF05)

- **Pré-condição:** deck aberto com ao menos um flashcard.
- **Passos:** 1) Tocar no botão de excluir flashcard.
- **Resultado esperado:** diálogo de confirmação aparece antes de excluir.
- **Resultado obtido:** mesmo padrão de CT04 — `_deletarFlashcard` em `study_screen.dart` exclui direto, sem diálogo.
- **Status:** **Falhou.**
- **Defeito:** mesmo risco de CT04, aplicado a flashcards.
- **Reteste (Bloco 4):** "Deletar card" abre "Excluir flashcard?" antes de apagar. **Passou.**

## CT06 — Editar flashcard existente (RF06)

- **Pré-condição:** deck aberto com ao menos um flashcard.
- **Passos:** 1) Tentar localizar uma opção de editar pergunta/resposta de um flashcard já criado.
- **Resultado esperado:** existe uma forma de editar e salvar via `PUT /flashcards/{id}`.
- **Resultado obtido:** não existe nenhuma opção de edição na UI (`study_screen.dart` só tem criar e excluir); `ApiService` não tem método que chame `PUT /flashcards/{id}`, apesar do endpoint existir e funcionar no backend.
- **Status:** **Falhou.**
- **Defeito:** funcionalidade de edição ausente ponta a ponta no frontend — backend pronto, sem uso.
- **Reteste (semana 7 — Bloco 5):** botão "Editar card" na tela de estudo abre um diálogo com pergunta/resposta preenchidas; ao salvar, chama `PUT /flashcards/{id}` e o card é atualizado na tela. Campos vazios são bloqueados no diálogo. Backend conferido (atualiza e devolve o card; id inexistente → `{"erro": ...}`). Coberto por testes automatizados (salvar e campo vazio). **Passou.**

## CT07 — Renomear deck existente (RF07)

- **Pré-condição:** existe ao menos um deck.
- **Passos:** 1) Tentar localizar uma opção de renomear um deck já criado.
- **Resultado esperado:** existe opção de editar o nome do deck.
- **Resultado obtido:** não existe endpoint `PUT /decks/{id}` no backend nem opção na UI (`home_screen.dart` só tem criar e excluir).
- **Status:** **Falhou.**
- **Defeito:** funcionalidade ausente dos dois lados — backend e frontend.
- **Reteste (semana 8 — Bloco 5):** criado `PUT /decks/{id}` (nome vazio → 400; id inexistente → `{"erro": ...}`) e botão de lápis em cada deck da Home, que abre um diálogo de renomear. Backend conferido. Coberto por teste automatizado (renomeia e mantém a contagem de cards). **Passou.**

## CT08 — Tocar em um modo de estudo (RF08)

- **Pré-condição:** tela de sessão de estudo aberta (`study_session_screen.dart`).
- **Passos:** 1) Tocar no card "Sessão Rápida" (ou "Prática Diária"/"Sessão Intensiva").
- **Resultado esperado:** uma sessão de estudo é iniciada seguindo a regra daquele modo.
- **Resultado obtido:** os cards são `Container`s sem `GestureDetector`/`onTap`; nada acontece ao tocar.
- **Status:** **Falhou.**
- **Defeito:** funcionalidade puramente decorativa, confirmando o ponto já levantado no diagnóstico do README.
- **Reteste (semanas 9-10 — Bloco 6):** os 3 cards agora abrem a escolha de deck e iniciam a sessão com as regras do modo (ver tabela em `requisitos.md`, RF08). Backend conferido (`modo` gravado na sessão; modo inválido → 400); **falta reexecutar o passo a passo manualmente no app.**

## CT09 — Buscar deck pelo nome (RF09)

- **Pré-condição:** Home com ao menos dois decks (ex.: "Matemática" e "Japonês").
- **Passos:** 1) Digitar `japones` no campo "Buscar deck pelo nome". 2) Digitar `xyz`.
- **Resultado esperado:** 1) só "Japonês" aparece (sem diferenciar acento/maiúscula). 2) aparece "Nenhum deck encontrado".
- **Status:** **Passou** — coberto por teste automatizado.

## CT10 — Buscar card dentro do deck (RF10)

- **Pré-condição:** deck aberto com os cards "2 + 2 → 4" e "Raiz de 9 → 3".
- **Passos:** 1) Tocar na lupa do cabeçalho. 2) Digitar `3`. 3) Tocar no resultado.
- **Resultado esperado:** só "Raiz de 9" aparece (achado pela resposta); ao tocar, a tela de estudo vai para esse card (2 / 2).
- **Status:** **Passou** — coberto por teste automatizado.

## CT11 — Importar deck de arquivo (RF11)

- **Pré-condição:** um arquivo `.apkg`, `.xlsx`, `.csv` ou `.pdf` com vocabulário japonês/português.
- **Passos:** 1) Na aba Decks, tocar em "Importar" → "Arquivo". 2) Escolher o arquivo. 3) Na revisão, desmarcar um card e tocar em "Importar N cards".
- **Resultado esperado:** o deck aparece na lista só com os cards marcados; no PDF, japonês na pergunta e português na resposta.
- **Status:** **Passou** — leitura de Anki (formato antigo e novo), Excel, CSV, export de texto do Anki e texto corrido coberta por `backend/test_backend.py`; revisão e gravação cobertas por `flutter_frontend/test/importacao_test.dart`. PDF: extração de texto + mesma regra de linhas (testada); **conferir com um PDF real no app**.

## CT12 — Foto → cards (RF12)

- **Pré-condição:** app no navegador ou no celular (no navegador, internet na primeira foto).
- **Passos:** 1) Dentro de um deck, tocar em "Da foto" → "Tirar foto" (ou "Escolher da galeria"). 2) Fotografar uma lista "水 - água / 火 - fogo". 3) Revisar e importar.
- **Resultado esperado:** os pares aparecem na revisão e entram no deck aberto.
- **Status:** **Parcial** — o motor do navegador (Tesseract.js 5.1.1, `por+jpn`) foi testado numa imagem com "Vocabulário - Lição 1 / 水 (mizu) - água / 火 - fogo / 山 - montanha / ありがとう - obrigado": os 4 pares saíram certos, com acento, e o título foi ignorado. A rota `/importar/texto` e a revisão estão cobertas por testes automatizados. **Falta:** foto real tirada no celular (ML Kit) e o fluxo clicando no navegador.

## Resumo dos defeitos

| Caso | Requisito | Status inicial (semana 4) | Severidade | Status na entrega |
|---|---|---|---|---|
| CT04 | RF04 | Falhou | Alta — perda de dados sem aviso | Passou (Bloco 4) |
| CT05 | RF05 | Falhou | Alta — perda de dados sem aviso | Passou (Bloco 4) |
| CT03 | RF03 | Falhou | Alta — app trava, sem forma de recuperar sem reiniciar | Passou (Bloco 4) |
| CT01 | RF01 | Falhou | Média — dado inconsistente, não causa crash | Passou (ajustes finais) |
| CT02 | RF02 | Falhou (parcial) | Média — só explorável via chamada direta à API | Passou (ajustes finais) |
| CT06 | RF06 | Falhou | Média — funcionalidade ausente, não quebra o que já existe | Passou (Bloco 5) |
| CT07 | RF07 | Falhou | Média — funcionalidade ausente, não quebra o que já existe | Passou (Bloco 5) |
| CT08 | RF08 | Falhou | Baixa — visual, não afeta dados nem fluxo principal | Implementado (Bloco 6) — conferir no app |
| CT09 | RF09 | — (criado no Bloco 7) | Baixa | Passou (Bloco 7) |
| CT10 | RF10 | — (criado no Bloco 7) | Baixa | Passou (Bloco 7) |
| CT11 | RF11 | — (criado depois do cronograma) | — | Passou (conferir PDF real no app) |
| CT12 | RF12 | — (criado depois do cronograma) | — | Parcial — OCR testado em imagem; falta foto real no celular |

## Priorização para correção

Ordem sugerida, considerando severidade e o que já está planejado nos próximos blocos do cronograma (Blocos 4 e 5, semanas 5–8):

1. **CT03 (RF03)** — tratamento de erro de API. Bloqueia o uso do app inteiro quando o backend cai; é pré-requisito para testar os demais itens com confiança.
2. **CT04 e CT05 (RF04/RF05)** — confirmação de exclusão. Risco de perda de dados é o impacto mais grave para o usuário.
3. **CT01 e CT02 (RF01/RF02)** — validação de nome/pergunta/resposta. Correção pequena, pode ser feita junto do Bloco 4 por ser rápida.
4. **CT06 e CT07 (RF06/RF07)** — edição de flashcard e deck. Já são o foco do Bloco 5 (semanas 7–8).
5. **CT08 (RF08)** — modos de estudo. Menor impacto imediato; mantém a posição do Bloco 6 no cronograma.
