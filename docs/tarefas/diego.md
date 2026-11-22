# Tarefas — Diego

Branch: `diego` · Regras de negócio dentro do banco (ver `docs/DIVISAO_TRABALHO.md`).

## Meus arquivos

| Arquivo | O que é |
|---------|---------|
| `database/02a_functions_views_triggers.sql` | Functions, views e triggers |
| `database/gerar_SGA_completo.ps1` | Script que monta o `SGA_completo.sql` |
| `database/SGA_completo.sql` | Todos os scripts na ordem (gerado, não editar) |
| `database/teste_dev_02a.sql` | Teste rápido da minha parte, para quem revisar o PR |
| `relatorio/functions_views_triggers.md` | Minha parte do relatório + dificuldades |
| `apresentacao/` | Modelo dos slides e gerador |

## Checklist

### S1 — Functions (até 01/11)
- [x] `fn_calcular_media(n1, n2, exame)` (RN01, RN03)
- [x] `fn_frequencia(id_matricula)`
- [x] `fn_situacao(id_matricula)` (RN02, RN03, RN04)
- [x] Auxiliares `fn_frequencia_calc` e `fn_situacao_calc` (recebem os valores, usadas pelos triggers)

### S2 — Views e triggers (até 08/11)
- [x] `vw_boletim` (+ `id_matricula` e `id_turma` para a tela de notas)
- [x] `vw_turmas_lotacao`
- [x] `vw_desempenho_turma`
- [x] `trg_valida_vagas` (BEFORE INSERT, RN05)
- [x] `trg_auditoria_nota` (AFTER UPDATE, RN08)
- [x] `trg_atualiza_situacao` (BEFORE UPDATE)
- [x] Extra: `trg_situacao_inicial` (BEFORE INSERT, média e situação já na inserção)

### S3 — Extras e script final (até 15/11)
- [x] `vw_faturamento_curso` (alunos ativos × mensalidade)
- [x] `fn_cr_aluno(id_aluno)` (opcional, ponto extra)
- [x] `gerar_SGA_completo.ps1` + primeira versão do `SGA_completo.sql`
- [ ] **Rodar `01_ddl.sql` → `02a` → `teste_dev_02a.sql` no MySQL e conferir esperado × obtido** (o script foi escrito sem um MySQL para testar)
- [x] Gerar o `SGA_completo.sql` de novo quando `02b`, `02c`, `03_dados` e `04_testes` estiverem prontos, e rodar do zero sem erro

### S4 — Slides (até 20/11)
- [x] Modelo dos slides com a minha parte preenchida
- [x] Juntar as partes de Guilherme, Mykael e Leo nos slides

## Também contribuo com
- [x] Minha parte do relatório técnico (`relatorio/functions_views_triggers.md`)
- [x] Dificuldades e soluções que enfrentei (no fim do mesmo arquivo)

## Como gerar o SGA_completo.sql

```powershell
powershell -ExecutionPolicy Bypass -File database\gerar_SGA_completo.ps1
```

Junta `01_ddl` → `02a` → `02b` → `02c` → `03_dados` → `04_testes` em um arquivo só. Rodar sempre que algum script mudar.
