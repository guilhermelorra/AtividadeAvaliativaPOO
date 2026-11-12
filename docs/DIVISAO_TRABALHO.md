# Divisão do Trabalho

> Segue o plano de ataque do grupo (26/10). Os combinados (textos exatos, hash de senha, nomes) fecham até 01/11. Cada integrante tem uma branch própria e um checklist em `docs/tarefas/`.

| Integrante | Branch | Responsabilidade principal | Arquivos |
|------------|--------|----------------------------|----------|
| **Guilherme** | `guilherme` | Modelagem (MER + modelo lógico), DDL, constraints, índices, massa de dados, procedures de cadastro de aluno e telas do Coordenador | `database/01_ddl.sql`, `database/02c_procedures_cadastro.sql`, `database/03_dados.sql`, `app/` (telas do Coordenador) |
| **Diego** | `diego` | Functions, views e triggers | `database/02a_functions_views_triggers.sql`, `database/SGA_completo.sql` |
| **Mykael** | `mykael` | Stored procedures e roteiro de testes | `database/02b_procedures.sql`, `database/04_testes.sql` |
| **Leo** | `leo` | Base da interface (login, menu por perfil) e telas do Secretário | `app/` |

## Responsabilidades compartilhadas

- **Relatório técnico:** cada um escreve a parte do que implementou; Guilherme consolida o PDF final.
- **Apresentação:** cada um monta os slides da sua parte (divisão do trabalho + dificuldades superadas).
- **"Principais Dificuldades e Soluções"** (mínimo 1 página): cada um contribui com suas dificuldades.
- **Prints da interface e casos de teste:** Leo + Mykael.

## Dependências entre as partes

```
Guilherme (DDL + dados) ─┬─> Diego (views, functions, triggers)
                         ├─> Mykael (procedures + testes)
                         └─> Leo (interface chama procedures/views)
```

O DDL é o primeiro gargalo: as demais partes dependem das tabelas. Sugestão: Guilherme entrega o `01_ddl.sql` primeiro para destravar o resto.

## Evitando conflitos de merge

- O antigo `03_programacao.sql` virou três arquivos, um por dono (`02a`, `02b` e `02c`), então ninguém edita o mesmo arquivo SQL.
- Fazer `git pull origin main` antes de abrir Pull Request.
- Merge sempre com **Create a merge commit** (sem squash nem rebase) e sem apagar a branch.
- Revisão em rodízio: Diego revisa o PR do Guilherme, Mykael o do Diego, Leo o do Mykael e Guilherme o do Leo.

## Marcos

| Marco | Quando |
|-------|--------|
| PR do `01_ddl.sql` | qui, 29/10/2026 |
| Combinados do grupo fechados | dom, 01/11/2026 |
| Tudo integrado e testado | dom, 15/11/2026 |
| Relatório pronto | sex, 20/11/2026 |
| Ensaio da apresentação | 21 e 22/11/2026 |
| **Entrega e apresentação** | **23/11/2026** |
