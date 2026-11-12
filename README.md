# SGA — Sistema de Gestão Acadêmica · Faculdade do Bug Infinito (FBI)

Trabalho Prático Integrado de Laboratório de Banco de Dados (LBD).
**Entrega e apresentação: 23/11/2026.**

O SGA centraliza o controle de turmas, matrículas, notas, frequência, históricos e perfis de acesso da Faculdade do Bug Infinito, substituindo as planilhas manuais. O projeto cobre a modelagem e programação do banco relacional (MySQL) e uma interface cliente de consulta e operação.

## Equipe

| Integrante | Branch |
|------------|--------|
| Guilherme  | `guilherme` |
| Diego      | `diego` |
| Mykael     | `mykael` |
| Leo        | `leo` |

> Divisão de tarefas, arquivos de cada um e prazos em [`docs/DIVISAO_TRABALHO.md`](docs/DIVISAO_TRABALHO.md).

## Tecnologias

- **Banco de dados:** MySQL + MySQL Workbench (8.0.16 ou superior: antes disso o MySQL ignora os CHECKs)
- **Interface:** linguagem a definir pelo grupo (Python, C#, Node.js, Java, C++...). **PHP é proibido.**
- **Comunicação interface ↔ banco:** somente via **Stored Procedures e Views**. Não pode trafegar SQL "cru" pela rede.
- **Senhas:** armazenadas com hash (SHA-256 ou BCRYPT). Nunca em texto puro.

## Estrutura do repositório

```
.
├── README.md
├── docs/
│   ├── REQUISITOS.md          # Enunciado resumido em checklist
│   ├── DIVISAO_TRABALHO.md    # Proposta de divisão entre os 4 integrantes
│   └── tarefas/               # Checklist individual (cada um na sua branch)
├── database/
│   ├── 01_ddl.sql                       # Banco, tabelas, índices e constraints (Guilherme)
│   ├── 02a_functions_views_triggers.sql # Functions, views e triggers (Diego)
│   ├── 02b_procedures.sql               # As 6 procedures do enunciado (Mykael)
│   ├── 02c_procedures_cadastro.sql      # Cadastro de aluno + vw_alunos (Guilherme)
│   ├── 03_dados.sql                     # Massa de dados, com os triggers já ativos (Guilherme)
│   └── 04_testes.sql                    # Roteiro de testes obrigatórios (Mykael)
├── app/                       # Código-fonte da interface (login + permissões por perfil)
├── relatorio/                 # Relatório técnico (.pdf) e diagramas MER / lógico
└── apresentacao/              # Slides da apresentação oral
```

## Como rodar o banco

1. Abra o MySQL Workbench e conecte na sua instância local.
2. Execute, **nesta ordem**: `01_ddl.sql` → `02a_functions_views_triggers.sql` → `02b_procedures.sql` → `02c_procedures_cadastro.sql` → `03_dados.sql` → `04_testes.sql`.

O `01_ddl.sql` apaga e recria o banco `sga_fbi`, então dá para rodar tudo de novo do zero quantas vezes quiser. Os dados rodam depois da programação para o `trg_valida_vagas` já validar a massa. Na entrega, o Diego junta tudo nessa ordem no `SGA_completo.sql`.

## Como rodar a interface

_A preencher quando a linguagem for definida (dependências + instruções de execução em `app/README.md`)._

## Fluxo de trabalho com Git

- `main`: versão integrada e estável. **Não commitar direto nela.**
- `guilherme`, `diego`, `mykael`, `leo`: uma branch por integrante, onde cada um trabalha na sua parte.
- Quando uma parte estiver pronta: abrir Pull Request da sua branch para `main` e pedir revisão de pelo menos um colega.
- Antes de começar a trabalhar, atualizar sua branch:

```bash
git checkout <sua-branch>
git pull origin main
```

- Mensagens de commit curtas e no imperativo, por exemplo: `Adiciona trigger de auditoria de notas`.

## Entregáveis (23/11/2026)

1. **Script SQL completo** (`database/`): tabelas, índices, constraints, triggers, views, functions, procedures, massa de dados e roteiro de testes.
2. **Código-fonte da interface** (`app/`, compactado em `.zip`): login, controle de permissões por perfil, dependências e instruções de execução.
3. **Relatório técnico** (`relatorio/`, `.pdf`): MER e modelo lógico, normalização até a 3FN, explicação dos objetos SQL, criptografia e perfis, seção "Principais Dificuldades Encontradas e Soluções" (mínimo 1 página), prints da interface e casos de teste.
4. **Apresentação** (`apresentacao/`, PPT ou PDF): divisão do trabalho e dificuldades técnicas superadas.

Checklist detalhado em [`docs/REQUISITOS.md`](docs/REQUISITOS.md).
