# Mojiki

## Diagnóstico do projeto

O Mojiki é um aplicativo de flashcards voltado para estudantes. A proposta é permitir que o usuário organize seus assuntos em decks, crie cards de pergunta e resposta e acompanhe seu estudo de maneira simples.

O projeto já possui a estrutura principal do aplicativo, mas ainda precisa evoluir em algumas partes importantes da experiência. O foco deste ciclo é organizar melhor o cronograma e definir com clareza quais tarefas podem ser adicionadas e quais informações não podem mais ser alteradas depois do registro.


## Objetivo

Organizar as atividades do projeto em um cronograma visual, permitindo:

- visualizar as tasks planejadas por semana;
- adicionar novas tasks quando necessário;
- informar o assunto, a descrição e o tamanho de cada task;
- acompanhar o andamento das atividades;
- preservar as tasks adicionadas no dia atual sem permitir sua edição.

## Quebrando em tasks

### Organização do cronograma

- [ ] Levantar os requisitos do cronograma — **M**
- [ ] Definir as semanas e os períodos do projeto — **P**
- [ ] Organizar as atividades por ordem de execução — **P**
- [ ] Definir o tamanho de cada task — **P**

### Adição de novas tasks

- [ ] Criar a opção de adicionar uma task — **P**
- [ ] Informar o título e a descrição da task — **P**
- [ ] Escolher a semana ou o período da atividade — **P**
- [ ] Informar o responsável pela task — **P**
- [ ] Mostrar a nova task no cronograma — **M**
- [ ] Permitir adicionar tasks mesmo depois do cronograma iniciado — **P**

### Regra de edição

- [ ] Identificar a data em que a task foi criada — **M**
- [ ] Bloquear a edição das tasks adicionadas no dia atual — **P**
- [ ] Esconder ou desabilitar a opção de editar essas tasks — **P**
- [ ] Permitir apenas a visualização das tasks bloqueadas — **P**
- [ ] Criar uma nova task quando for necessário registrar uma alteração — **P**

### Validação e testes

- [ ] Verificar se uma task pode ser adicionada corretamente — **P**
- [ ] Verificar se a task aparece na semana escolhida — **P**
- [ ] Confirmar que uma task criada hoje não pode ser editada — **P**
- [ ] Confirmar que as tasks antigas continuam disponíveis para consulta — **P**
- [ ] Testar o cronograma com várias tasks — **M**
- [ ] Registrar os problemas encontrados — **P**

## Regra das tasks

O professor pode adicionar novas tasks ao cronograma a qualquer momento. Porém, depois que uma task é adicionada no dia atual, ela não pode ser editada.

A task deve permanecer disponível para visualização, com suas informações originais. Para registrar uma mudança de atividade, deve ser adicionada uma nova task, mantendo o histórico da anterior.

## Critérios de aceite

- Uma nova task pode ser adicionada informando, no mínimo, título, descrição e semana.
- A task aparece no cronograma depois de ser registrada.
- A data de criação fica associada à task.
- Tasks adicionadas hoje não apresentam opção de edição.
- Tasks bloqueadas continuam disponíveis para visualização.
- O usuário consegue diferenciar uma task nova de uma task já existente.
- Uma nova task pode ser adicionada sem alterar as demais atividades.
- O cronograma permanece organizado por semana e por ordem de criação.

## Tamanho das tasks

- **P — Pequena:** pode ser concluída em algumas horas.
- **M — Média:** pode levar aproximadamente um dia.
- **G — Grande:** pode levar de dois a três dias e talvez precise ser dividida.

As estimativas servem para ajudar na organização do cronograma e podem ser revisadas durante o planejamento, sem modificar uma task que já foi registrada no dia atual.

## Cronograma do projeto

| Semana | Foco | Entrega esperada |
|---|---|---|
| 1 | Levantamento | Requisitos principais do projeto |
| 2 | Planejamento | Organização das semanas e das tasks |
| 3 | Cadastro | Opção de adicionar novas tasks |
| 4 | Visualização | Tasks exibidas no cronograma |
| 5 | Regra de bloqueio | Tasks criadas hoje sem edição |
| 6 | Validação | Testes de adição e visualização |
| 7 | Ajustes | Correção dos problemas encontrados |
| 8 | Organização | Melhorias no agrupamento por semana |
| 9 | Acompanhamento | Revisão do andamento das atividades |
| 10 | Testes gerais | Verificação do fluxo completo |
| 11 | Correções finais | Ajustes apontados nos testes |
| 12 | Documentação | Atualização do diagnóstico e das tasks |
| 13 | Entrega | Revisão final do projeto |

## Fluxo esperado

1. O professor acessa o cronograma.
2. O professor escolhe a opção de adicionar uma task.
3. O professor informa os dados da atividade.
4. A task é registrada com a data atual.
5. A task aparece na semana escolhida.
6. A task criada hoje fica disponível somente para visualização.
7. Se houver uma nova atividade ou alteração necessária, o professor adiciona outra task.

## Fora do escopo neste momento

- Editar tasks criadas no dia atual.
- Apagar ou substituir o histórico do cronograma.
- Criar usuários reais e permissões diferentes para cada perfil.
- Automatizar a distribuição das tasks entre as semanas.
- Criar notificações ou lembretes automáticos.

## Entrega esperada

Ao final deste ciclo, o Mojiki deverá apresentar um cronograma organizado e permitir que o professor acrescente novas tasks. As tasks criadas no dia atual deverão permanecer sem opção de edição, garantindo um registro claro do planejamento feito em cada dia.
