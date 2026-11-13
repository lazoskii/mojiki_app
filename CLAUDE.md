# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Mojiki é um app de flashcards (foco em japonês) feito para um projeto de faculdade: **backend FastAPI + SQLite** em `backend/` e **frontend Flutter** em `flutter_frontend/`. Código, comentários, mensagens de erro e docs são em português.

## Regras do projeto

- **Não editar `README.md`** sem pedido explícito. O README guarda o diagnóstico e o cronograma de 12 semanas (Blocos 1–7). As mudanças são registradas em `docs/` (ex.: `docs/mudancas_2026-11-11.md`), em `docs/requisitos.md` (RF..) e em `docs/casos_de_teste.md` (CT..).
- **Depois de cada mudança impactante, atualizar `NOTAS_APOSTILA.md`** (fica no gitignore, nunca entra em commit). É uma apostila para o dono estudar programação pelo próprio código:
  - se a mudança ensina um conceito novo, adicione um capítulo curto com um trecho real do código;
  - acrescente sempre uma linha no "Diário de mudanças";
  - escreva curto, sem relatório de teste nem "como testei".
- As dependências do backend vão no `backend/venv` (Python 3.14), nunca no Python global. Ao instalar um pacote, adicione-o também ao `backend/requirements.txt`.
- `decks_para_importar/` são decks prontos em CSV (`Pergunta;Resposta`, UTF-8 com BOM). Eles ficam **fora** do banco de propósito: o banco começa vazio e não existe seed. Os CSVs são gerados por `decks_para_importar/_gerar_decks.py`.
- A versão antiga do app fica na branch `versao-antiga`, com worktree em `../mojiki_app_antigo`. Ela serve só de referência.

## Comandos

Backend (rodar dentro de `backend/`):
```
venv\Scripts\uvicorn main:app --reload             # API em http://localhost:8000
venv\Scripts\python -m unittest -v                 # todos os testes
venv\Scripts\python -m unittest test_backend.TestFormatos.test_excel   # um teste
```
Os testes chamam as funções de rota direto (`main.importar_deck(...)`), sem cliente HTTP. Eles usam um banco temporário via variável `MOJIKI_DB`, definida antes do `import main`.

Frontend (rodar dentro de `flutter_frontend/`, Flutter 3.41.9):
```
flutter run -d chrome                               # usa http://127.0.0.1:8000 (emulador Android: 10.0.2.2)
flutter run -d chrome --dart-define=API_URL=https://mojiki-api.onrender.com
flutter test                                        # todos
flutter test test/importacao_test.dart --plain-name "trecho do nome"
flutter analyze
```
No Git Bash, um build com `--base-href "/mojiki_app/"` precisa de `MSYS_NO_PATHCONV=1`.

## Arquitetura

**Backend**
- `main.py`: todas as rotas. Validação de entrada falha com HTTP 400 e `{"detail"}`, pelo helper `obrigatorio()`. Um id inexistente responde **200 com `{"erro": "..."}`**, e o frontend depende dessa convenção.
- `database.py`: cria as tabelas e faz migrações simples com `ALTER TABLE` dentro de `create_tables`. O caminho do banco vem de `MOJIKI_DB` e, por padrão, é `backend/flashcards.db`.
- `models.py`: modelos Pydantic.
- `user_id` é fixo em 1, porque ainda não existe autenticação.
- `importador.py`: transforma arquivos em uma prévia `{nome_sugerido, cards, ignoradas, origem}`.
  - Formatos: Anki `.apkg` (zip + SQLite, `anki21b` comprimido com zstd), CSV/TXT, Excel (openpyxl), PDF (pypdf) e imagem (Tesseract no servidor).
  - O CSV usa `_detectar_separador`, e não o `csv.Sniffer`.
  - Texto sem estrutura é pareado por `parear_linhas`/`separar_japones_portugues`, que reconhecem o japonês pelas faixas Unicode.
  - `limpar()` remove só o que parece tag HTML.
- Fluxo de importação em duas etapas:
  1. `/importar/previa` (upload) ou `/importar/texto` (texto vindo do OCR) devolvem a prévia.
  2. O usuário revisa os cards.
  3. `/decks/importar` grava tudo numa transação com rollback, ou `/decks/{id}/flashcards/lote` adiciona a um deck que já existe.
- Sessões de estudo (`study_sessions`, com coluna `modo`): o app inicia a sessão, registra cada resposta e finaliza.

**Frontend** (`flutter_frontend/lib`)
- `main.dart`: go_router com URLs por hash.
  - Um `ShellRoute` (`screens/app_shell.dart`, com NavigationBar) envolve `/home`, `/study-session` e `/progress`.
  - `/study/:deckId?modo=&voltar=` fica fora do shell.
- `services/api_service.dart`: único ponto de acesso HTTP.
  - A URL vem de `String.fromEnvironment('API_URL')`.
  - O timeout é de 70 s com API remota, porque o Render free demora a acordar.
  - As respostas são decodificadas explicitamente em UTF-8.
- `screens/study_screen.dart`: UI otimista. A resposta aparece na hora e as chamadas ao servidor entram numa fila serializada (`_naFila`/`_filaServidor`), para que a sessão anterior finalize antes da próxima.
- OCR no aparelho por export condicional em `services/ocr_service.dart`:
  - web: `ocr_web.dart` chama `web/ocr.js` (Tesseract.js via CDN, idiomas `['por','jpn']` nessa ordem para manter os acentos);
  - mobile: `ocr_mobile.dart` usa o ML Kit;
  - se o aparelho falhar, `widgets/importar.dart` manda a imagem para o backend.
- `theme/app_theme.dart` define a paleta "Washi" (`AppColors`), `cardDecoration()` e outros estilos. Os formulários usam `widgets/app_campo.dart`.
- `services/progress_service.dart` guarda o progresso local (SharedPreferences): sequência de dias e último deck.

## Deploy

- **Frontend:**
  - `.github/workflows/pages.yml` roda `flutter test` e `flutter build web` com `API_URL` vindo da variável de repositório `vars.API_URL`, e publica em https://lazoskii.github.io/mojiki_app/.
  - No GitHub, Settings → Pages → Source precisa estar em **GitHub Actions**. Com "Deploy from a branch", o Jekyll publica o README no lugar do app.
- **Backend:**
  - `render.yaml` (Blueprint, plano free, `rootDir: backend`, autoDeploy) publica em https://mojiki-api.onrender.com.
  - `MOJIKI_DB=/tmp/mojiki_online.db`, então o banco online é efêmero e começa vazio a cada reinício.
  - O Tesseract não está instalado lá, então o OCR online depende do aparelho.
