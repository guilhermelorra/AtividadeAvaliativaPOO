# Tarefas — Mykael

Branch: `mykael` · Proposta inicial, sujeita a ajuste pelo grupo (ver `docs/DIVISAO_TRABALHO.md`).

## Responsabilidade principal
Stored procedures e roteiro de testes.

## Checklist
- [x] `sp_LoginUsuario`
- [x] `sp_matricular_aluno` (RN05, RN06, RN09; `SIGNAL SQLSTATE '45000'`)
- [x] `sp_lancar_notas`
- [x] `sp_lancar_exame` (somente se "Em exame")
- [x] `sp_historico_aluno`
- [x] `sp_fechar_semestre` (cursor + transação; somente Coordenador)
- [x] `04_testes.sql`: os 9 testes obrigatórios
- [x] Casos de teste e resultados para o relatório

## Também contribuo com
- [ ] Minha parte do relatório técnico (`relatorio/`)
- [ ] Meus slides da apresentação (`apresentacao/`)
- [ ] Dificuldades e soluções que enfrentei (para a seção obrigatória do relatório)
