# Casos de teste da interface

Os testes abaixo foram executados na própria aplicação, logada com cada perfil, sobre a massa de dados do `03_dados.sql` (banco recriado do zero antes da execução). As mensagens de erro vêm do banco: a interface apenas as exibe. Os testes das regras de negócio no próprio banco estão na seção anterior (`04_testes.sql`, 39 verificações, 39 OK).

## Acesso e perfis

| # | Perfil | Cenário | Esperado | Obtido | Resultado |
|---|---|---|---|---|---|
| I1 | (nenhum) | Login `coord.ana` com senha errada | Acesso negado, sem dizer qual campo errou | "Login ou senha inválidos." | OK |
| I2 | (nenhum) | Entrar com a senha em branco | A tela pede os dados antes de consultar o banco | "Informe o login e a senha." | OK |
| I3 | Secretário | Login com `sec.carla` e conferência do menu | Menu sem "Notas e exame", "Fechar semestre" e "Relatórios" | Menu só com Início, Turmas, Boletim, Histórico, Matricular e Alunos, e painel sem o cartão de faturamento | OK |
| I4 | Coordenador | Login com `coord.ana` e conferência do menu | Menu completo, com a seção de coordenação | Menu com Notas e exame, Fechar semestre, Relatórios e Auditoria, e painel com o cartão de faturamento | OK |
| I5 | Secretário | Chamar `sp_fechar_semestre` com o usuário do Secretário | Banco recusa | "Apenas o Coordenador pode fechar o semestre." | OK |
| I6 | Secretário | Chamar `sp_lancar_notas` com o usuário do Secretário | Banco recusa | "Apenas o Coordenador pode lançar notas." | OK |
| I7 | Secretário | Chamar `sp_lancar_exame` com o usuário do Secretário | Banco recusa | "Apenas o Coordenador pode lançar exame." | OK |

![I1: login inválido](img/telas/02_login_invalido.png) ![I2: dados incompletos](img/telas/03_login_incompleto.png)

![I3: menu do Secretário](img/telas/10_sec_painel.png)

Nos testes I5 a I7 a tela do Secretário não oferece os botões; por isso a chamada foi feita diretamente ao repositório da aplicação, e o diálogo mostrado é o mesmo que a tela exibe para qualquer erro do banco. Isso comprova que o banco barra o perfil mesmo quando a interface é contornada.

![I5: fechar semestre como Secretário](img/telas/27_sec_barrado_fechar.png) ![I6: lançar notas como Secretário](img/telas/28_sec_barrado_notas.png) ![I7: lançar exame como Secretário](img/telas/29_sec_barrado_exame.png)

## Cadastro de alunos e matrícula (Secretário)

| # | Cenário | Esperado | Obtido | Resultado |
|---|---|---|---|---|
| I8 | Cadastrar aluno com dados válidos | Aluno criado e listado | "Aluno cadastrado com sucesso." e a lista passa a mostrar o novo aluno | OK |
| I9 | Cadastrar aluno com RA já existente | Banco recusa | "Já existe um aluno com este RA." | OK |
| I10 | Excluir aluno que tem matrículas | Banco recusa e orienta | "Aluno tem matrículas: tranque o aluno em vez de excluir." | OK |
| I11 | Matricular aluno que já está na turma | Banco recusa | "Aluno já matriculado nesta turma." | OK |
| I12 | Matricular aluno sem o pré-requisito (Estruturas de Dados sem Algoritmos) | Banco recusa e diz qual falta | "Falta pré-requisito: o aluno não foi aprovado em Algoritmos." | OK |
| I13 | Matricular aluno válido em turma aberta com vaga | Matrícula criada | "Matrícula realizada com sucesso!" | OK |
| I14 | Consultar boletim e histórico de um aluno | Linhas do aluno, com notas, frequência e situação | Tabelas exibidas, com o CR do aluno no topo | OK |
| I14b | Histórico de aluno sem disciplina concluída | O CR não é inventado | O cartão mostra "sem disciplinas concluídas" | OK |

![I8: cadastro realizado](img/telas/13_sec_cadastro_ok.png) ![I9: RA repetido](img/telas/15_sec_cadastro_erro_ra.png) ![I10: exclusão recusada](img/telas/16_sec_excluir_com_matricula.png)

![I11: matrícula duplicada](img/telas/20_sec_matricula_duplicada.png) ![I12: falta pré-requisito](img/telas/21_sec_matricula_prerequisito.png) ![I13: matrícula realizada](img/telas/24_sec_matricula_ok.png)

![I14: histórico do aluno, com o CR](img/telas/26_sec_historico.png)

![I14b: aluno sem CR](img/telas/26b_sec_historico_sem_cr.png)

## Notas, exame e fechamento (Coordenador)

| # | Cenário | Esperado | Obtido | Resultado |
|---|---|---|---|---|
| I15 | Lançar N1 = 7,5, N2 = 8,0 e 3 faltas para um aluno sem notas | Notas gravadas; média 7,75 e situação Aprovado calculadas pelo banco | Tabela atualizada: média 7,75, frequência 96,25 %, Aprovado | OK |
| I16 | Informar N1 = 11 | A tela recusa antes de enviar (e o `CHECK` do banco também recusaria) | "N1: a nota deve estar entre 0 e 10." | OK |
| I17 | Lançar exame 5,0 para aluno Em Exame (N1 6,0 e N2 7,0) | Média final 5,75 e Aprovado | Situação passou de Em Exame para Aprovado, média 5,75 | OK |
| I18 | Lançar exame para aluno que não está Em Exame | A tela recusa e explica | "Exame só pode ser lançado para matrícula Em Exame. Daniel Pacheco está como: Aprovado." | OK |
| I19 | Fechar o semestre com matrícula sem N2 | Fechamento recusado, nada muda | "Matrícula 17 (Alice Monteiro) sem N1 ou N2: lance as notas antes de fechar o semestre." | OK |
| I20 | Completar as notas e fechar o semestre 2026.2 | Turmas encerradas e resumo por situação | Resumo exibido; turmas do semestre passam a Encerrada | OK |
| I21 | Abrir os relatórios | Desempenho, lotação e faturamento | Três abas com os dados das views; faturamento em reais | OK |
| I22 | Abrir a Auditoria depois de lançar notas (I15 e I17) | Uma linha em `log_nota` por campo alterado, com valor antigo, novo, usuário e data | Linhas das notas e do exame lançados, com o usuário Ana Beatriz Moura | OK |
| I23 | Comparar o painel inicial dos dois perfis | Só o Coordenador vê o faturamento | Secretário com 3 cartões; Coordenador com 4 | OK |

![I15: notas lançadas](img/telas/33_coord_notas_apos_lancamento.png)

![I16: nota inválida](img/telas/34_coord_nota_invalida.png) ![I18: exame indisponível](img/telas/37_coord_exame_indisponivel.png)

![I22: auditoria das notas lançadas](img/telas/38_coord_auditoria.png)

![I23: painel do Coordenador](img/telas/29_coord_inicio.png)

![I19: fechamento recusado](img/telas/45_coord_fechar_recusado.png) ![I20: semestre fechado](img/telas/46_coord_fechar_ok.png)
