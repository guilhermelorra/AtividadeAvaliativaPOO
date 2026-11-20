# Procedures, criptografia, perfis e testes

Parte do Mykael. Arquivos: `database/02b_procedures.sql` e `database/04_testes.sql`.

## 1. Procedures

O sistema acessa o banco só por `CALL sp_...` e `SELECT` nas views. A média e a
situação da matrícula nunca são calculadas nas procedures: elas gravam `n1`, `n2`,
`exame` e `faltas`, e o `trg_atualiza_situacao` faz o resto. Assim a regra de negócio
(RN01 a RN04) existe em um lugar só.

| Procedure | O que faz | Regras |
|---|---|---|
| `sp_LoginUsuario(login, hash)` | Devolve id, nome, e-mail e perfil; resultado vazio se não conferir | senha nunca volta |
| `sp_matricular_aluno(aluno, turma, usuário)` | Cria a matrícula e devolve o `id_matricula` | RN05, RN06, RN09 |
| `sp_lancar_notas(matrícula, n1, n2, faltas, usuário)` | Grava notas e faltas | RN07, RN08; só Coordenador |
| `sp_lancar_exame(matrícula, exame, usuário)` | Grava o exame | só se `Em Exame`; RN03; só Coordenador |
| `sp_historico_aluno(aluno)` | Boletim do aluno por semestre | |
| `sp_fechar_semestre(semestre, usuário)` | Encerra as turmas e fecha as situações | cursor + transação; só Coordenador |

Além do mínimo: a matrícula só entra em turma `Aberta` e recusa matrícula repetida;
notas só se lançam em turma `Aberta`.

### sp_matricular_aluno
Confere, nesta ordem: usuário, aluno, turma, aluno `Ativo` (RN09), turma `Aberta`,
matrícula repetida e pré-requisito (RN06: `Aprovado` em toda disciplina exigida; a
mensagem diz qual falta). A vaga (RN05) é barrada pelo `trg_valida_vagas`, que trava a
linha da turma (`FOR UPDATE`): duas matrículas simultâneas na última vaga entram em fila
e a segunda já enxerga a turma lotada.

### sp_fechar_semestre
Tudo ou nada. Dentro de `START TRANSACTION`, um cursor percorre as matrículas das turmas
abertas do semestre:
- `Em Exame` sem exame lançado vira `Reprovado por Nota`;
- `Cursando` (falta N1 ou N2) recusa o fechamento inteiro, com a mensagem apontando o
  aluno, e o `EXIT HANDLER` faz `ROLLBACK`.

No fim as turmas viram `Encerrada` e o `COMMIT` confirma. A conferência de perfil vem
antes do `START TRANSACTION`, então um Secretário barrado não mexe em nada.

## 2. Criptografia e perfis

- **Senha:** SHA-256 em hexadecimal minúsculo, `CHAR(64)`. A massa de dados grava
  `SHA2('Senha@123', 256)` e a interface gera o mesmo hash antes de chamar a
  `sp_LoginUsuario`. A senha em texto nunca chega ao banco nem é guardada.
- **Comparação:** por bytes (`utf8mb4_bin`), então o login diferencia maiúscula de
  minúscula e o hash só confere em minúsculo. A resposta não diz se errou o login ou a senha.
- **Perfis:** `Coordenador` e `Secretario`. O banco barra o que a tela esconde: lançar
  notas, lançar exame e fechar semestre exigem Coordenador, mesmo que alguém chame a
  procedure direto.

## 3. Roteiro de testes (`04_testes.sql`)

Rode o arquivo inteiro depois do `03_dados.sql`. Os testes que devem falhar rodam dentro
da `sp_teste_erro`, que captura o erro, então não é preciso desligar o "parar no erro" do
Workbench. Os testes 1 a 10 rodam numa transação que termina em `ROLLBACK`, e o 11 apaga o
que cria: a massa de dados continua intacta. No fim sai a tabela esperado × obtido.

Resultado da execução em um MySQL 8.0.46 limpo: **35 verificações, 35 OK, 0 falhas**.

| Teste | Cenário | Esperado | Obtido |
|---|---|---|---|
| 1 | Login com senha errada, e usuário inexistente | resultado vazio | vazio nos dois; com a senha certa, 1 linha (Coordenador) |
| 2 | Aluno 5 em turma 3 (4 de 4 vagas) | falha, turma lotada | `Turma lotada: a turma 3 já tem 4 de 4 vagas ocupadas.` |
| 3 | Aluno 16 em Estruturas de Dados, reprovado em Algoritmos | falha, pré-requisito | `Falta pré-requisito: o aluno não foi aprovado em Algoritmos.` |
| 4 | Alunos 19 (Trancado) e 20 (Formado) | falha | `Aluno Trancado não pode se matricular: só alunos Ativos.` e o mesmo para Formado |
| 5 | N1 = 11,0 e N2 = -1,0 | falha pelo CHECK | `Check constraint 'ck_matricula_n1' is violated.` (e `ck_matricula_n2`) |
| 6 | N1 6,0 e N2 7,0, depois exame 5,0 | `Em Exame`, depois média 5,75 e `Aprovado` | confere; com exame 2,0 a média é 3,75 e vira `Reprovado por Nota` |
| 7 | Média 9,0 com 25 faltas em 80 aulas | `Reprovado por Falta` | média 9,00, frequência 68,75 %, `Reprovado por Falta` |
| 8 | Lançar N1 7,0 e N2 8,0 numa matrícula sem notas | 2 linhas em `log_nota` | 2 linhas (n1 e n2, NULL → valor), usuário 1 |
| 9 | Consultar as 3 views | 35, 5 e 5 linhas | 35, 5 e 5 linhas |
| 10 | Secretário fecha o semestre | falha | `Apenas o Coordenador pode fechar o semestre.` |
| 11 | Fechar semestre com e sem notas completas | recusa com ROLLBACK; depois encerra | nada muda na recusa; no sucesso a turma vira `Encerrada` e `Em Exame` vira `Reprovado por Nota` |

## 4. Principais dificuldades e soluções

(Parágrafo do Mykael: escrever com as palavras dele. Pontos que apareceram: o
`CREATE PROCEDURE` e o `START TRANSACTION` fazem commit implícito, o que exigiu montar os
testes em duas fases; testes que devem falhar paravam o script no Workbench, resolvido com
um handler que captura a mensagem; e a conferência de perfil antes da transação, para o
`ROLLBACK` do handler não desfazer trabalho alheio.)
