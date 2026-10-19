# Requisitos do Trabalho (checklist)

Resumo do enunciado `TrabalhoFinalLBD`. Marque `[x]` conforme for concluindo.

## Segurança e perfis

- [ ] Tela de login com verificação de senha
- [ ] Senha armazenada com hash (SHA-256 ou BCRYPT), nunca em texto puro
- [ ] Perfil **Secretário**: cadastrar/editar/excluir alunos, matricular, consultar turmas, emitir boletins e históricos. **Sem** acesso a financeiro nem fechamento de turmas
- [ ] Perfil **Coordenador**: acesso total (notas, encerramento de semestre, relatórios de desempenho e faturamento por curso)
- [ ] `sp_LoginUsuario` valida credenciais e devolve dados do usuário (sem a senha) + perfil

## Regras de negócio

- [ ] **RN01** Média parcial = (N1 + N2) / 2
- [ ] **RN02** Parcial ≥ 7,0 → Aprovado · entre 4,0 e 6,9 → Em Exame · < 4,0 → Reprovado por Nota
- [ ] **RN03** Média final = (média parcial + exame) / 2; aprovado se ≥ 5,0
- [ ] **RN04** Frequência < 75% → Reprovado por Falta (independe das notas)
- [ ] **RN05** Turma não excede o limite de vagas
- [ ] **RN06** Matrícula só com pré-requisitos aprovados
- [ ] **RN07** Notas entre 0,0 e 10,0 (CHECK constraint)
- [ ] **RN08** Alteração de nota gera registro automático em `log_nota`
- [ ] **RN09** Aluno "Trancado" ou "Formado" não pode se matricular

## Banco de dados (3FN)

Tabelas: - [ ] `usuario` - [ ] `curso` - [ ] `disciplina` - [ ] `pre_requisito` - [ ] `professor` - [ ] `aluno` - [ ] `turma` - [ ] `matricula` - [ ] `log_nota`

Massa de dados mínima:

- [ ] 5 usuários (2 Coordenadores + 3 Secretários, com senha em hash)
- [ ] 3 cursos
- [ ] 6 disciplinas
- [ ] 5 professores
- [ ] 20 alunos
- [ ] 5 turmas
- [ ] 35 matrículas

## Objetos SQL

**Views**

- [ ] `vw_boletim`
- [ ] `vw_turmas_lotacao`
- [ ] `vw_desempenho_turma`

**Functions**

- [ ] `fn_calcular_media(n1, n2, exame)`
- [ ] `fn_frequencia(id_matricula)`
- [ ] `fn_situacao(id_matricula)`
- [ ] `fn_cr_aluno(id_aluno)` _(opcional)_

**Stored Procedures**

- [ ] `sp_LoginUsuario(p_login, p_senha_hash)`
- [ ] `sp_matricular_aluno(p_id_aluno, p_id_turma, p_id_usuario)` (valida RN05, RN06, RN09; erro via `SIGNAL SQLSTATE '45000'`)
- [ ] `sp_lancar_notas(p_id_matricula, p_n1, p_n2, p_faltas, p_id_usuario)`
- [ ] `sp_lancar_exame(p_id_matricula, p_exame, p_id_usuario)` (somente se situação = "Em exame")
- [ ] `sp_historico_aluno(p_id_aluno)`
- [ ] `sp_fechar_semestre(p_semestre, p_id_usuario)` (cursores + transação; somente Coordenador)

**Triggers**

- [ ] `trg_valida_vagas` (BEFORE INSERT em `matricula`)
- [ ] `trg_auditoria_nota` (AFTER UPDATE em `matricula`)
- [ ] `trg_atualiza_situacao` (BEFORE UPDATE em `matricula`)

## Roteiro de testes (`database/04_testes.sql`)

1. [ ] Login com senha incorreta / usuário inexistente → falha ou vazio
2. [ ] Matrícula em turma lotada → falha (`45000`)
3. [ ] Matrícula sem pré-requisito → falha
4. [ ] Matrícula de aluno Trancado → falha
5. [ ] Nota fora do intervalo (ex.: 11,0) → falha (CHECK)
6. [ ] Notas → exame → validação da situação final
7. [ ] Média 9,0 com frequência < 75% → "Reprovado por Falta"
8. [ ] Alteração de notas → registros em `log_nota`
9. [ ] Execução e consulta das 3 views

## Interface

- [ ] Tela de login
- [ ] Controle de permissões por perfil (Secretário × Coordenador)
- [ ] Telas: cadastro de alunos, matrícula, lançamento de notas, relatórios
- [ ] Acesso ao banco **somente** via procedures e views (sem PHP, sem SQL cru)
- [ ] Arquivo de dependências + instruções de execução

## Relatório técnico (.pdf)

- [ ] Diagramas MER e modelo lógico relacional
- [ ] Justificativa de normalização até a 3FN
- [ ] Explicação de procedures, views, functions, triggers, criptografia e perfis
- [ ] "Principais Dificuldades Encontradas e Soluções" (mínimo 1 página)
- [ ] Prints da interface (login, cadastro, matrícula, lançamento de notas, relatórios por perfil)
- [ ] Casos de teste e resultados (login inválido, acesso não autorizado por perfil)

## Apresentação (PPT ou PDF)

- [ ] Slides com divisão do trabalho e dificuldades técnicas superadas
