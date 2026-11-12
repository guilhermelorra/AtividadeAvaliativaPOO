# Tarefas — Guilherme

Branch: `guilherme` · Arquitetura do banco + telas do Coordenador (ver `docs/DIVISAO_TRABALHO.md`).

Arquivos: `database/01_ddl.sql`, `database/02c_procedures_cadastro.sql`, `database/03_dados.sql`, `app/` (telas do Coordenador), `relatorio/`.

## S1 · Banco de pé (até 01/11)
- [ ] Adicionar Diego, Mykael e Leo no repo (Settings → Collaborators)
- [ ] Proteger a `main` (Settings → Branches: exigir PR com 1 aprovação)
- [x] MER e modelo lógico (`relatorio/modelo_dados.md`)
- [ ] Exportar o EER Diagram do Workbench para `relatorio/img/`
- [x] `01_ddl.sql`: as 9 tabelas + `curso.valor_mensalidade` e `turma.status`; PK, FK, UNIQUE e CHECKs (turno, perfil, status, situação, notas 0–10)
- [x] Índices: FKs, ra, cpf, login
- [x] PR do DDL até quinta, 29/10

## S2 · Dados e cadastro (até 08/11)
- [ ] `02c`: `sp_cadastrar_aluno`, `sp_editar_aluno`, `sp_excluir_aluno` + `vw_alunos`
- [ ] `03_dados.sql`: 5 usuários (2 Coord. + 3 Secr.), 3 cursos, 6 disciplinas, 5 professores, 20 alunos, 5 turmas, 35 matrículas
- [ ] Cenários de teste do Mykael (turma lotada, pré-requisito, Trancado/Formado, Em Exame, média ≥ 9 com faltas > 25%), em 2026.1 encerrado e 2026.2 aberto
- [ ] Comentário no topo do `03_dados.sql` com logins/senhas de teste e IDs dos cenários

## S3 · Telas do Coordenador (até 15/11)
- [ ] Lançar notas e exame
- [ ] Fechar semestre (`sp_fechar_semestre`)
- [ ] Relatórios: desempenho, lotação e faturamento

## S4 · Relatório (até 20/11)
- [ ] MER, modelo lógico e justificativa da 3FN no relatório
- [ ] Juntar as partes de todos no PDF final
- [ ] Prints das telas do Coordenador
- [ ] Meu parágrafo em "Dificuldades e Soluções"
- [ ] Meus slides da apresentação
