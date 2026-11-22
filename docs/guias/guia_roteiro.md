# 1. Ordem da apresentação

A apresentação segue os slides de `apresentacao/SGA_apresentacao.pptx` (20 slides). Cada pessoa fala só da sua parte. O tempo abaixo é uma sugestão: ajustem ao limite que o professor der.

| Slides | Quem fala | O que é | Tempo sugerido |
|---|---|---|---|
| 1 a 3 | Qualquer um (combinem antes) | Abertura, "as regras ficam no banco" e divisão do trabalho | 1 min |
| 4 a 6 | Guilherme | Modelagem, DDL, 3FN e telas do Coordenador | 3 min |
| 7 a 12 | Diego | Functions, views, triggers e dificuldades | 3 min |
| 13 a 15 | Mykael | Procedures, hash de senha e os 39 testes | 3 min |
| 16 a 18 | Leo | Interface, login e controle de acesso | 3 min |
| 19 e 20 | O grupo | Roteiro da demonstração e a demonstração ao vivo | 4 min |

**Dois formatos dos slides.** O arquivo `apresentacao/SGA_apresentacao.pptx` é o tradicional. O `apresentacao/SGA_apresentacao.html` é a versão interativa: abra no Chrome, aperte `F` para tela cheia e avance com as setas. No slide do modelo, passe o mouse nas tabelas e clique para dar zoom, ou clique em "Explicar as relações" e avance com a seta. Há também um simulador da situação do aluno, o fluxo dos triggers, os cartões que viram e a troca de perfil. A tecla `G` mostra a lista de slides e `Esc` sai do modo guiado.

Regras de ouro para a fala:

- Quem termina diz o nome do próximo ("agora o Diego mostra como o banco calcula as notas"). A troca fica natural.
- Cada um fala o que está no seu guia, na parte "Em um minuto". Não improvisem número que não conhecem.
- Se o professor perguntar sobre a parte de outra pessoa, respondam o que sabem e passem para ela: "o Mykael fez essa parte, ele explica melhor".

# 2. Antes de começar: preparar o computador

Façam isto uma hora antes e de novo uns 10 minutos antes de apresentar.

1. **Ligar o MySQL.** Abra o MySQL Workbench e confirme que a conexão local abre.
2. **Recriar o banco do zero.** No Workbench, abra `database/SGA_completo.sql` e execute o arquivo inteiro (o raio amarelo). Ele apaga e recria o banco `sga_fbi`, com 20 alunos, 5 turmas e 35 matrículas. Sempre que ensaiarem, rodem de novo para voltar ao estado inicial, senão a demonstração muda (por exemplo, o aluno que já foi matriculado não pode ser matriculado outra vez).
3. **Dizer ao app qual é a senha do MySQL.** O app lê a senha de variáveis de ambiente. Os comandos estão logo abaixo desta lista.
4. **Abrir o app pelo IntelliJ.** Abra a pasta `app` como projeto Maven, crie uma configuração de execução da classe `SgaApplication` e coloque `SGA_DB_USER` e `SGA_DB_PASSWORD` em "Environment variables". Clique em executar.
5. **Ou abrir pelo terminal**, se o Maven estiver instalado: `mvn clean compile exec:java` na pasta `app`, na mesma janela em que as variáveis foram definidas.
6. **Conferir.** A tela de login deve abrir. Entre com `coord.ana` e a senha `Senha@123`. Se aparecer o painel Início com cartões e gráfico, está tudo certo.
7. **Deixar à mão**: o relatório em PDF (`relatorio/Relatorio_SGA.pdf`), os slides abertos em tela cheia e o Workbench com o `SGA_completo.sql` aberto, para o caso de o professor pedir para ver o código.

Comandos do passo 3, no PowerShell, trocando pela senha do seu MySQL:

```text
$env:SGA_DB_USER = "root"
$env:SGA_DB_PASSWORD = "a-senha-do-seu-mysql"
```

Atalho para ensaiar: o script `ensaio\ensaio.ps1` faz os passos 1 a 6 sozinho e depois mostra o roteiro da demonstração, um passo por vez. Rode no PowerShell, na raiz do projeto: `powershell -ExecutionPolicy Bypass -File ensaio\ensaio.ps1`. Ele pede a senha do MySQL (não grava), recria o banco com o `SGA_completo.sql`, compila e abre o app. Se o MySQL não estiver na porta 3306, acrescente `-Porta 3307` (ou a porta que usar). Com `-SoPreparar` ele só recria o banco e compila.

# 3. Logins de teste

Todos com a senha `Senha@123`.

| Login | Perfil | Para que usar na demonstração |
|---|---|---|
| coord.ana | Coordenador | Lançar notas, exame, auditoria, relatórios e fechar semestre |
| coord.bruno | Coordenador | Reserva |
| sec.carla | Secretário | Matricular, cadastrar aluno, boletim e histórico |
| sec.diego | Secretário | Reserva |
| sec.elisa | Secretário | Reserva |

# 4. A demonstração, passo a passo

Banco recém-criado com o `SGA_completo.sql`. Tempo total: uns 4 minutos.

| Passo | Quem entra | O que fazer | O que aparece |
|---|---|---|---|
| 1 | coord.ana, senha errada | Digitar `senha-errada` e clicar em Entrar | "Login ou senha inválidos." |
| 2 | sec.carla | Entrar e olhar o menu | Menu sem Notas e exame, Fechar semestre, Relatórios e Auditoria; painel sem o cartão de faturamento |
| 3 | sec.carla | Menu Matricular: aluno Rafael Domingues, turma Estruturas de Dados | "Falta pré-requisito: o aluno não foi aprovado em Algoritmos." |
| 4 | sec.carla | Menu Matricular: aluno Queila Macedo, turma Banco de Dados | "Matrícula realizada com sucesso!" |
| 5 | sec.carla | Menu Histórico, aluno 3 | Histórico com o CR no topo |
| 6 | coord.ana | Notas e exame, turma Programação Orientada a Objetos: Daniel Pacheco, notas 7,5 e 8 e 3 faltas | A média e a situação (Aprovado) aparecem na hora |
| 7 | coord.ana | Na mesma tela, Bernardo Cavalcante (Em Exame): exame 5 | Média final 5,75, Aprovado |
| 8 | coord.ana | Menu Auditoria | Linhas novas: quem mudou, qual campo, valor antigo e novo (é o trigger funcionando) |
| 9 | coord.ana | Menu Fechar semestre, 2026.2 | Recusado: "Matrícula 17 (Alice Monteiro) sem N1 ou N2..." |

Se sobrar tempo, mostrem os Relatórios (desempenho, lotação e faturamento em reais).

# 5. Se algo der errado

| Problema | O que fazer |
|---|---|
| O app não abre ou não conecta | Confirmar que o MySQL está ligado, que as variáveis `SGA_DB_USER` e `SGA_DB_PASSWORD` foram definidas na mesma janela em que o app foi aberto e que o banco existe (rodar o `SGA_completo.sql`) |
| "Access denied for user" | A senha do MySQL está errada na variável de ambiente |
| A demonstração deu resultado diferente do esperado | O banco já foi usado. Rodar o `SGA_completo.sql` de novo e repetir |
| O app trava no meio da apresentação | Seguir com os prints do relatório PDF, seção 6 (telas) e seção 7 (casos de teste), que mostram tudo o que a demonstração mostraria |
| O professor pede para ver o código | Abrir o arquivo no Workbench (SQL) ou no IntelliJ (Java) e ir ao trecho citado no guia de cada pessoa |

# 6. O que o professor provavelmente quer ver

- Que as regras de negócio estão **no banco** (functions, triggers, procedures), e não na tela.
- Que a interface só usa **procedures e views**, sem SQL solto.
- Que a **senha** não é guardada em texto puro.
- Que o **perfil** é respeitado: o Secretário não fecha semestre nem lança nota, e o banco recusa mesmo que alguém chame a procedure direto.
- Que existem **testes** com resultado esperado e obtido (os 39 do `04_testes.sql`).
- Que o **modelo** está normalizado (3FN) e que vocês sabem explicar a única redundância (média final e situação, mantidas pelos triggers).
