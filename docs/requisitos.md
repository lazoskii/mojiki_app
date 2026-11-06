# Documento de Requisitos — Mojiki

Semana 3 do cronograma (ver [README.md](../README.md), Bloco 2). Os requisitos abaixo foram levantados a partir do diagnóstico já feito no README ("Pontos de melhoria") e de leitura direta do código atual (`backend/main.py`, `flutter_frontend/lib/`). Cada requisito vira um caso de teste em [casos_de_teste.md](casos_de_teste.md).

Não entram aqui os itens já resolvidos (RF de acerto/erro, Bloco 1) nem os itens fora de escopo do momento (busca, `user_id` fixo — ver README, ficam como backlog).

## RF01 — Validação de nome do deck

O sistema não deve permitir a criação de um deck com nome vazio ou composto só por espaços. A validação deve existir tanto no frontend (`home_screen.dart`) quanto no backend (`POST /decks`), já que hoje o backend aceita qualquer string sem checagem.

## RF02 — Validação de pergunta/resposta do flashcard

O sistema não deve permitir a criação de um flashcard com `pergunta` ou `resposta` vazias. Assim como RF01, a validação deve existir no backend (`POST /flashcards`), não só no cliente.

## RF03 — Tratamento de erro nas chamadas de API

Quando uma chamada à API falhar (backend fora do ar, timeout ou erro de rede), a tela correspondente deve sair do estado de carregamento e exibir uma mensagem de erro com opção de tentar novamente — nunca travar indefinidamente no spinner. Vale para toda chamada feita via `ApiService`, não só para as que já têm try/catch hoje.

## RF04 — Confirmação antes de excluir um deck

Antes de excluir um deck, o sistema deve exibir um diálogo de confirmação informando que todos os flashcards daquele deck também serão apagados. A exclusão só deve ocorrer se o usuário confirmar.

## RF05 — Confirmação antes de excluir um flashcard

Antes de excluir um flashcard, o sistema deve exibir um diálogo de confirmação. A exclusão só deve ocorrer se o usuário confirmar.

## RF06 — Edição de flashcard

O usuário deve conseguir editar a pergunta e a resposta de um flashcard existente a partir da tela de estudo, com a alteração persistida via `PUT /flashcards/{id}` (endpoint já existe no backend, falta a chamada no frontend).

## RF07 — Edição (renomeação) de deck

O usuário deve conseguir renomear um deck existente. Isso exige criar um endpoint `PUT /decks/{id}` no backend (não existe hoje) e uma opção de edição na tela inicial.

## RF08 — Modos de estudo funcionais

Ao tocar em um dos cards de modo de estudo ("Sessão Rápida", "Prática Diária", "Sessão Intensiva") na tela `study_session_screen.dart`, o sistema deve iniciar de fato uma sessão de estudo — hoje esses cards são apenas visuais (`Container` sem `onTap`). O comportamento exato de cada modo (ex.: limite de tempo ou de cards) deve ser definido antes da implementação (Bloco 6).

**Regras definidas (Bloco 6):** tocar no modo abre a lista de decks com cards; ao escolher, a tela de estudo abre com os cards embaralhados, um cronômetro regressivo e o modo gravado na `StudySession` (coluna `modo`). Quando o tempo acaba, a sessão é finalizada e o resultado aparece.

| Modo | Tempo | Cards | Regra extra |
|---|---|---|---|
| Sessão Rápida | 5 min | até 10 | — |
| Prática Diária | 15 min | todos | — |
| Sessão Intensiva | 30 min | todos | card marcado como "Errei" volta pro fim da fila |


---

Próximo passo: revisar esta lista com o grupo/professor antes de seguir para os casos de teste.
