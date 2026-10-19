# Divisão do Trabalho (proposta inicial)

> Rascunho para o grupo discutir e ajustar. Cada integrante tem uma branch própria e um checklist em `docs/tarefas/`.

| Integrante | Branch | Responsabilidade principal | Arquivos |
|------------|--------|----------------------------|----------|
| **Guilherme** | `guilherme` | Modelagem (MER + modelo lógico), DDL, constraints, índices e massa de dados | `database/01_ddl.sql`, `database/02_dados.sql` |
| **Diego** | `diego` | Views, functions e triggers | `database/03_programacao.sql` (seções Views / Functions / Triggers) |
| **Mykael** | `mykael` | Stored procedures e roteiro de testes | `database/03_programacao.sql` (seção Procedures), `database/04_testes.sql` |
| **Leo** | `leo` | Interface: login, permissões por perfil, telas | `app/` |

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

- `03_programacao.sql` é editado por Diego e Mykael. Cada um fica na sua seção (marcadas com comentários), ou o arquivo pode ser dividido em `03a_views_functions_triggers.sql` e `03b_procedures.sql` se o grupo preferir.
- Fazer `git pull origin main` antes de abrir Pull Request.

## Marcos sugeridos

| Marco | Quando |
|-------|--------|
| DDL + dados prontos | a combinar |
| Objetos SQL + testes passando | a combinar |
| Interface integrada ao banco | a combinar |
| Relatório e slides finalizados | até 20/11/2026 |
| **Entrega e apresentação** | **23/11/2026** |
