# 1. Em um minuto

**A sua parte em uma frase:** você escreveu as **stored procedures**, que são as "portas de entrada" do banco, e o **roteiro de testes** que prova que tudo funciona. São 6 procedures no arquivo `database/02b_procedures.sql` (login, matricular, lançar notas, lançar exame, histórico e fechar semestre) e um script de testes, `database/04_testes.sql`, com 12 testes e 39 verificações.

**Por que isso importa:** a interface Java não faz nenhum INSERT nem UPDATE. Ela só chama as suas procedures e consulta views. Por isso é nas suas procedures que ficam as regras de quem pode fazer o quê (Secretário ou Coordenador), a validação de pré-requisito, e o fechamento do semestre "tudo ou nada". E os testes mostram ao professor, com resultado esperado contra resultado obtido, que as regras funcionam.

**Roteiro para falar em voz alta (cerca de 1 minuto):**

> Eu fiz as stored procedures do sistema e o roteiro de testes. A interface não escreve direto nas tabelas: ela só chama as minhas procedures. O login recebe o login e o hash SHA-256 da senha e devolve os dados do usuário, nunca a senha, e não diz se errou o login ou a senha. A matrícula confere se o aluno está Ativo, se a turma está aberta, se ele já não está matriculado, se já não foi aprovado naquela disciplina e se tem aprovação nos pré-requisitos; a regra de vagas é barrada por um trigger do Diego. Lançar notas e lançar exame só o Coordenador pode, uma nota já lançada não pode ser apagada, e eu não calculo média nem situação nas procedures: só gravo as notas e o trigger faz o resto, para a regra existir em um lugar só. O fechamento de semestre usa um cursor e uma transação: percorre as matrículas e, se alguma estiver sem nota, desfaz tudo com ROLLBACK, então é tudo ou nada. Por fim, escrevi o roteiro de testes: 39 verificações, todas OK, incluindo login errado, turma lotada, sem pré-requisito, aluno trancado, nota 11, reprovação por falta com média 9, repetir disciplina já aprovada, apagar nota e o ROLLBACK do fechamento. Ele não suja a massa de dados e mostra uma tabela de esperado contra obtido.

**Números para ter na cabeça:** 6 procedures, 12 testes agrupados em 39 verificações, todas OK. Erros de regra sempre são `SIGNAL SQLSTATE '45000'` com uma mensagem legível.

# 2. Palavras que você precisa saber

- **Stored procedure:** um programa guardado dentro do banco, com nome, que você chama com `CALL`. Diferente da function, ela pode gravar dados, devolver tabelas de resultado e controlar transações. Exemplo da vida real: o balcão de atendimento. Você pede "matricular o aluno X na turma Y" e o balcão confere tudo antes de fazer.
- **Parâmetro `IN`:** valor que entra na procedure. Nós usamos o prefixo `p_` (parâmetro) nos nomes e `v_` (variável) para as variáveis locais.
- **SIGNAL SQLSTATE '45000':** lança um erro de propósito. `45000` é o código de "erro definido pelo programador" e `MESSAGE_TEXT` é a frase que o usuário vê. A procedure para na hora e nada do que vem depois executa.
- **Transação:** um pacote de operações do tipo "tudo ou nada". `START TRANSACTION` abre o pacote, `COMMIT` confirma tudo e `ROLLBACK` desfaz tudo. Exemplo: uma transferência bancária: ou sai de uma conta **e** entra na outra, ou nada acontece.
- **Commit implícito:** alguns comandos (como `CREATE PROCEDURE` e `START TRANSACTION`) confirmam sozinhos o que estava pendente. Por isso não dá para desfazer com ROLLBACK algo que veio antes deles.
- **Cursor:** um "ponteiro" que percorre o resultado de um SELECT **linha por linha**, como o dedo seguindo uma lista. Você abre (`OPEN`), pega a próxima linha (`FETCH`) e fecha (`CLOSE`).
- **Handler:** um "plano B" para quando algo dá errado ou acaba. `CONTINUE HANDLER FOR NOT FOUND` roda quando o `FETCH` não tem mais linhas e depois o código continua. `EXIT HANDLER FOR SQLEXCEPTION` roda quando acontece qualquer erro e depois **sai** do bloco.
- **RESIGNAL:** relança o **mesmo erro** que o handler pegou, para quem chamou saber que deu errado. Sem ele, o handler engoliria o erro.
- **LOOP, LEAVE e rótulo:** `ler: LOOP ... END LOOP` é um laço sem fim, com o nome `ler`. `LEAVE ler` sai dele.
- **Bloco BEGIN ... END aninhado:** um BEGIN dentro de outro. No MySQL, `DECLARE` de cursor e handler tem que vir logo no começo de um bloco, antes de qualquer outro comando. Por isso a `sp_fechar_semestre` abre um bloco interno.
- **COLLATE utf8mb4_bin:** collation é a regra de comparação de texto. A padrão do nosso banco ignora maiúscula e acento (`'a'` = `'A'`). `utf8mb4_bin` compara **byte a byte**: maiúscula é diferente de minúscula e acento conta.
- **SHA-256 e hash:** hash é uma "impressão digital" de um texto: a mesma senha sempre gera o mesmo código de 64 caracteres hexadecimais, e é praticamente impossível voltar do código para a senha. SHA-256 é o algoritmo usado. No banco: `SHA2('Senha@123', 256)`.
- **Salt:** texto aleatório misturado à senha antes do hash, diferente para cada usuário, para que senhas iguais não gerem hashes iguais. **Nosso sistema não usa salt.**
- **CHECK:** regra de validação criada junto com a tabela (por exemplo, nota entre 0 e 10). Se o dado não cumpre, o banco recusa. É do Guilherme, mas os seus testes dependem dele.
- **FK (chave estrangeira):** coluna que só aceita valores que existem em outra tabela. Exemplo: `matricula.id_turma` só aceita uma turma que existe.
- **EXISTS e NOT EXISTS:** perguntam "existe pelo menos uma linha assim?". `IF EXISTS (SELECT 1 FROM ...)` é verdadeiro se o SELECT devolver alguma linha.
- **SELECT ... INTO:** guarda o resultado do SELECT em variáveis. Se o SELECT não achar nenhuma linha, as variáveis ficam como estavam (aqui, NULL).
- **LAST_INSERT_ID():** devolve o id que o último INSERT acabou de gerar (o AUTO_INCREMENT). Usamos para devolver o `id_matricula` novo.
- **REGEXP_LIKE:** confere se um texto bate com um padrão. `'^[0-9]{4}[.][12]$'` significa: começa, 4 dígitos, um ponto, o dígito 1 ou 2, e acaba. Serve para validar o semestre (`2026.2`).
- **FOR UPDATE:** lê as linhas e as trava até o fim da transação, para outra sessão não mexer nelas ao mesmo tempo.
- **PREPARE / EXECUTE:** executam um comando SQL que está guardado como texto. Os testes usam isso para rodar um comando que **deve falhar** dentro de uma procedure que captura o erro.
- **GET DIAGNOSTICS:** lê detalhes do erro que acabou de acontecer, como o `MESSAGE_TEXT` (a mensagem).
- **Variável de usuário (`@nome`):** variável da sessão do Workbench, que sobrevive entre comandos. Os testes guardam resultados em `@situacao_antes`, por exemplo.
- **Tabela temporária e ENGINE = MEMORY:** tabela que só existe na sua conexão e some no fim. A MEMORY fica na memória e **não é transacional**: um ROLLBACK não apaga o que foi gravado nela.
- **DELIMITER:** comando do cliente que troca o `;` por `$$` enquanto criamos uma procedure, para o cliente não cortar o comando no primeiro `;` do corpo.
- **Perfil:** `Secretario` ou `Coordenador`. O Coordenador faz tudo; o Secretário não lança notas, não lança exame e não fecha semestre.
- **Regras RN05, RN06, RN07, RN08, RN09:** RN05 limite de vagas; RN06 só se matricula com pré-requisito aprovado; RN07 nota de 0 a 10; RN08 auditoria de nota; RN09 aluno Trancado ou Formado não se matricula.

# 3. O código, linha por linha

Como ler esta parte: cada bloco tem o trecho **exatamente como está no arquivo**, e logo abaixo uma tabela explicando. A coluna da esquerda é o número da linha (ou o intervalo). A primeira metade é o `02b_procedures.sql`. A segunda metade é o `04_testes.sql`.

## PARTE A: o arquivo 02b_procedures.sql

## Cabeçalho do arquivo (linhas 1 a 43)

> O cabeçalho diz que este é o arquivo do Mykael, que depende do `01_ddl.sql` (tabelas) e do 02a (a `vw_boletim` e os triggers que calculam média e situação), e que pode ser rodado de novo porque cada procedure tem DROP IF EXISTS. Lista as 6 procedures e os combinados do grupo: erro de regra é SIGNAL SQLSTATE 45000 com mensagem legível (a interface só mostra essa mensagem), perfis com a grafia exata `Secretario` e `Coordenador`, senha em SHA-256 hexadecimal minúsculo. Depois vêm 5 decisões: (1) média e situação nunca são calculadas aqui, quem faz é o `trg_atualiza_situacao`; (2) quem grava nota grava o próprio id em `matricula.id_usuario` no mesmo UPDATE, porque é daí que o `trg_auditoria_nota` tira o usuário do log; (3) nota fora de 0 a 10 é barrada pelo CHECK do DDL; (4) só se matricula e só se lançam notas em turma Aberta; (5) lançar notas e exame exige Coordenador.

## Preparação (linhas 45 a 54)

### USE e DROP (linhas 45 a 52)

```sql
USE sga_fbi;

DROP PROCEDURE IF EXISTS sp_fechar_semestre;
DROP PROCEDURE IF EXISTS sp_historico_aluno;
DROP PROCEDURE IF EXISTS sp_lancar_exame;
DROP PROCEDURE IF EXISTS sp_lancar_notas;
DROP PROCEDURE IF EXISTS sp_matricular_aluno;
DROP PROCEDURE IF EXISTS sp_LoginUsuario;
```

| Linha | O que faz |
|-------|-----------|
| 45 | `USE sga_fbi;` escolhe o banco. |
| 47 a 52 | Um `DROP PROCEDURE IF EXISTS` para cada procedure. Apaga se existir, não dá erro se não existir. Por isso o arquivo pode ser rodado várias vezes. |

### Troca do delimitador (linha 54)

```sql
DELIMITER $$
```

| Linha | O que faz |
|-------|-----------|
| 54 | `DELIMITER $$`: a partir daqui cada procedure termina em `END$$` e não em `;`. O motivo: o corpo da procedure tem vários `;`. A volta ao normal é na linha 424. |

## sp_LoginUsuario (linhas 66 a 75)

> Resumo: devolve uma linha (id_usuario, nome, email, perfil) se o login e o hash conferem; senão devolve o resultado vazio. Nunca devolve a senha e não diz se foi o login ou a senha que errou. A comparação é por bytes (`utf8mb4_bin`): o login diferencia maiúscula de minúscula e o hash tem que ser o hexadecimal minúsculo.

### Parâmetros (linhas 66 a 70)

```sql
CREATE PROCEDURE sp_LoginUsuario(
    IN p_login       VARCHAR(30),
    IN p_senha_hash  CHAR(64)
)
BEGIN
```

| Linha | O que faz |
|-------|-----------|
| 66 | Cria a procedure `sp_LoginUsuario` (prefixo `sp_`). |
| 67 | `IN p_login VARCHAR(30)`: o login digitado. 30 é o tamanho da coluna `usuario.login`. |
| 68 | `IN p_senha_hash CHAR(64)`: o **hash** da senha, não a senha. A interface Java calcula o SHA-256 antes de chamar. Um SHA-256 em hexadecimal tem sempre 64 caracteres. |
| 70 | `BEGIN`. |

### Consulta (linhas 71 a 75)

```sql
    SELECT id_usuario, nome, email, perfil
      FROM usuario
     WHERE login      COLLATE utf8mb4_bin = p_login
       AND senha_hash COLLATE utf8mb4_bin = p_senha_hash;
END$$
```

| Linha | O que faz |
|-------|-----------|
| 71 | Escolhe só quatro colunas: id, nome, e-mail e perfil. **A coluna `senha_hash` não está na lista**, então a senha nunca volta, nem em forma de hash. |
| 72 | Da tabela `usuario`. |
| 73 | `login COLLATE utf8mb4_bin = p_login`: compara o login byte a byte. Por quê: a collation padrão do banco ignora maiúscula, e `COORD.ANA` entraria como `coord.ana`. Com `_bin`, só o texto exato serve. |
| 74 | Mesma coisa com o hash. Por quê: o CHECK da tabela só aceita hash em minúsculo, e queremos que o hash enviado seja idêntico ao guardado. |
| 75 | `END$$`. |

Como a procedure é só um SELECT, quando não há linha compatível o resultado vem **vazio**, e o mesmo vazio aparece se errou o login ou se errou a senha. Isso impede que alguém descubra, tentando, quais logins existem.

## sp_matricular_aluno (linhas 94 a 175)

> Resumo: cria a matrícula e devolve uma linha com o `id_matricula`. RN09: aluno Trancado ou Formado não se matricula. RN06: só com "Aprovado" em todos os pré-requisitos da disciplina. RN05: a turma não pode passar das vagas, e quem barra é o `trg_valida_vagas` do Diego, que trava a turma. Além do mínimo: a turma precisa estar Aberta, o aluno não pode já estar matriculado nela e não pode se matricular de novo numa disciplina em que já foi "Aprovado" (quem reprovou pode repetir). O exemplo de uso do comentário, `CALL sp_matricular_aluno(10, 4, 3)`, funciona com a massa de dados. Atenção: o aluno 10 ocupa a última vaga da turma 4; depois dele, qualquer outra matrícula na turma 4 dá "Turma lotada".

### Parâmetros (linhas 94 a 99)

```sql
CREATE PROCEDURE sp_matricular_aluno(
    IN p_id_aluno    INT,
    IN p_id_turma    INT,
    IN p_id_usuario  INT
)
BEGIN
```

| Linha | O que faz |
|-------|-----------|
| 94 | Cria a procedure. |
| 95 a 97 | Três parâmetros de entrada: qual aluno, qual turma e **qual usuário** está fazendo a matrícula (para ficar registrado em `matricula.id_usuario`). |
| 99 | `BEGIN`. |

### Variáveis (linhas 100 a 104)

```sql
    DECLARE v_status_aluno  VARCHAR(8);
    DECLARE v_status_turma  VARCHAR(9);
    DECLARE v_id_disciplina INT;
    DECLARE v_faltando      VARCHAR(100);
    DECLARE v_msg           VARCHAR(128);
```

| Linha | O que faz |
|-------|-----------|
| 100 e 101 | Variáveis para o status do aluno e o da turma. Os tamanhos 8 e 9 são os das colunas (`Trancado` e `Encerrada` são os maiores valores). |
| 102 | A disciplina da turma, para procurar os pré-requisitos dela. |
| 103 | O nome do pré-requisito que está faltando, se houver. |
| 104 | A mensagem de erro que será montada. |

### Conferir usuário e aluno (linhas 106 a 113)

```sql
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE id_usuario = p_id_usuario) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário não encontrado.';
    END IF;

    SELECT status INTO v_status_aluno FROM aluno WHERE id_aluno = p_id_aluno;
    IF v_status_aluno IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno não encontrado.';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 106 a 108 | Se **não existe** usuário com esse id, lança o erro "Usuário não encontrado." `NOT EXISTS (SELECT 1 ...)` é o jeito de perguntar "não há nenhuma linha?". |
| 110 | Busca o status do aluno e guarda em `v_status_aluno`. |
| 111 a 113 | Se ficou NULL, o aluno não existe: erro "Aluno não encontrado." Como a coluna `status` é `NOT NULL`, NULL só pode significar que o SELECT não achou a linha. Conferir se as coisas existem **primeiro** deixa as mensagens claras e evita comparar com NULL depois. |

### Conferir a turma (linhas 115 a 121)

```sql
    SELECT status, id_disciplina
      INTO v_status_turma, v_id_disciplina
      FROM turma
     WHERE id_turma = p_id_turma;
    IF v_status_turma IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma não encontrada.';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 115 a 118 | Busca de uma vez o status da turma e a disciplina dela. |
| 119 a 121 | Se `v_status_turma` ficou NULL, a turma não existe: "Turma não encontrada." (mesmo raciocínio do aluno: a coluna é `NOT NULL`). |

### RN09 e turma aberta (linhas 123 a 132)

```sql
    IF v_status_aluno COLLATE utf8mb4_bin <> 'Ativo' THEN
        SET v_msg = CONCAT('Aluno ', v_status_aluno,
                           ' não pode se matricular: só alunos Ativos.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_status_turma COLLATE utf8mb4_bin <> 'Aberta' THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Turma encerrada: não aceita novas matrículas.';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 123 | Se o status do aluno é diferente de `'Ativo'`, não pode se matricular. O `COLLATE utf8mb4_bin` faz a comparação ser exata, igual ao CHECK da tabela. É a RN09: pega Trancado e Formado de uma vez. |
| 124 a 126 | Monta a mensagem com o status real, por exemplo "Aluno Trancado não pode se matricular: só alunos Ativos." e lança o erro. |
| 129 a 132 | Se a turma não está `'Aberta'`, recusa: "Turma encerrada: não aceita novas matrículas." Depois do fechamento do semestre a situação é definitiva. |

### Matrícula repetida (linhas 134 a 137)

```sql
    IF EXISTS (SELECT 1 FROM matricula
                WHERE id_aluno = p_id_aluno AND id_turma = p_id_turma) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno já matriculado nesta turma.';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 134 e 135 | Pergunta se já existe uma matrícula desse aluno nessa turma. |
| 136 | Se existe, erro "Aluno já matriculado nesta turma." Sem isso, a pessoa veria a mensagem técnica da chave UNIQUE (`id_aluno`, `id_turma`) do DDL. A UNIQUE continua lá como segunda proteção. |

### Já aprovado nesta disciplina (linhas 139 a 149)

```sql
    -- Quem já passou na disciplina não se matricula de novo, nem em outra
    -- turma. Reprovado (por nota ou por falta) pode repetir.
    IF EXISTS (SELECT 1
                 FROM matricula m
                 JOIN turma t ON t.id_turma = m.id_turma
                WHERE m.id_aluno = p_id_aluno
                  AND t.id_disciplina = v_id_disciplina
                  AND m.situacao = 'Aprovado') THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Aluno já foi aprovado nesta disciplina.';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 139 e 140 | Comentário: quem já passou na disciplina não se matricula de novo, nem em outra turma. Reprovado (por nota ou por falta) pode repetir. |
| 141 a 146 | `IF EXISTS (SELECT 1 ...)`: pergunta se existe alguma matrícula **deste aluno** (`m.id_aluno = p_id_aluno`) em **qualquer turma da mesma disciplina** (`t.id_disciplina = v_id_disciplina`, ligando a matrícula à turma pelo JOIN) com situação `'Aprovado'`. Por que olhar a disciplina e não só a turma: a turma onde ele passou é outra (de outro semestre), mas a disciplina é a mesma. A checagem da turma repetida (linhas 134 a 137) não pega esse caso. |
| 147 e 148 | Se existe, erro "Aluno já foi aprovado nesta disciplina." A procedure para ali e nada é gravado. |
| 149 | Fecha o IF. |

Por que só `'Aprovado'` impede: quem foi reprovado por nota ou por falta precisa poder refazer a disciplina. A regra olha apenas quem **já passou**; quem ainda está "Cursando" em outra turma da mesma disciplina não é barrado por esta checagem. Ela vem **antes** da dos pré-requisitos, e a mensagem é específica para quem já passou.

### RN06: pré-requisitos (linhas 151 a 164)

```sql
    SELECT d.nome
      INTO v_faltando
      FROM pre_requisito pr
      JOIN disciplina d ON d.id_disciplina = pr.id_disciplina_requisito
     WHERE pr.id_disciplina = v_id_disciplina
       AND NOT EXISTS (
           SELECT 1
             FROM matricula m
             JOIN turma t ON t.id_turma = m.id_turma
            WHERE m.id_aluno = p_id_aluno
              AND t.id_disciplina = pr.id_disciplina_requisito
              AND m.situacao = 'Aprovado')
     ORDER BY d.nome
     LIMIT 1;
```

| Linha | O que faz |
|-------|-----------|
| 151 e 152 | Vai guardar em `v_faltando` o **nome** da disciplina que falta. |
| 153 e 154 | Parte da tabela `pre_requisito` e junta com `disciplina` para pegar o nome do requisito. |
| 155 | Só os pré-requisitos **da disciplina da turma** onde o aluno quer entrar. |
| 156 a 162 | `AND NOT EXISTS (...)`: fica só o pré-requisito para o qual **não existe** uma matrícula do aluno, em alguma turma daquela disciplina, com situação `'Aprovado'`. Ou seja, descobre quais pré-requisitos o aluno ainda não cumpriu. Só "Aprovado" conta: Cursando, Em Exame e reprovado não valem. |
| 163 e 164 | `ORDER BY d.nome LIMIT 1`: se faltar mais de um, pega só o primeiro por ordem alfabética, para a mensagem apontar um nome. |

Se o aluno cumpriu todos os pré-requisitos (ou a disciplina não tem nenhum), o SELECT não devolve linha e `v_faltando` continua NULL.

### Recusar quando falta pré-requisito (linhas 165 a 169)

```sql
    IF v_faltando IS NOT NULL THEN
        SET v_msg = CONCAT('Falta pré-requisito: o aluno não foi aprovado em ',
                           v_faltando, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 165 | Se `v_faltando` tem um nome, falta pré-requisito. |
| 166 a 168 | Monta e lança "Falta pré-requisito: o aluno não foi aprovado em Algoritmos." (com o nome real). |

### Gravar e devolver o id (linhas 171 a 175)

```sql
    INSERT INTO matricula (id_aluno, id_turma, id_usuario)
    VALUES (p_id_aluno, p_id_turma, p_id_usuario);

    SELECT LAST_INSERT_ID() AS id_matricula;
END$$
```

| Linha | O que faz |
|-------|-----------|
| 171 e 172 | `INSERT` da matrícula, informando só aluno, turma e usuário. Os outros campos usam os valores padrão da tabela: data de hoje, 0 faltas, situação "Cursando". Neste momento disparam os triggers do Diego: o `trg_valida_vagas` (RN05, recusa se lotada) e o `trg_situacao_inicial` (calcula média e situação). |
| 174 | `SELECT LAST_INSERT_ID() AS id_matricula` devolve à interface o id da matrícula recém-criada. |
| 175 | `END$$`. |

## sp_lancar_notas (linhas 191 a 243)

> Resumo: grava n1, n2 e faltas da matrícula e o id de quem lançou. A média e a situação saem do `trg_atualiza_situacao`, e a alteração vai para o `log_nota` pelo `trg_auditoria_nota`. n1 ou n2 podem vir NULL **só enquanto aquela nota ainda não existe** (dá para lançar a N1 antes da N2); uma nota já lançada não pode ser apagada, só trocada por outro valor. Nota fora de 0 a 10 é barrada pelo CHECK (RN07). Só o Coordenador pode.

### Parâmetros e variáveis (linhas 191 a 202)

```sql
CREATE PROCEDURE sp_lancar_notas(
    IN p_id_matricula  INT,
    IN p_n1            DECIMAL(4,2),
    IN p_n2            DECIMAL(4,2),
    IN p_faltas        INT,
    IN p_id_usuario    INT
)
BEGIN
    DECLARE v_perfil       VARCHAR(11);
    DECLARE v_status_turma VARCHAR(9);
    DECLARE v_n1_atual     DECIMAL(4,2);
    DECLARE v_n2_atual     DECIMAL(4,2);
```

| Linha | O que faz |
|-------|-----------|
| 191 a 197 | Cinco parâmetros: a matrícula, as duas notas (`DECIMAL(4,2)`), as faltas e o usuário que está lançando. |
| 198 | `BEGIN`. |
| 199 e 200 | Variáveis para o perfil do usuário (11 caracteres, o tamanho de `Coordenador`) e o status da turma (9, o tamanho de `Encerrada`). |
| 201 e 202 | **Novas:** `v_n1_atual` e `v_n2_atual` guardam as notas que a matrícula **já tem**. Existem para comparar "o que está no banco" com "o que está chegando". |

### Só o Coordenador (linhas 204 a 211)

```sql
    SELECT perfil INTO v_perfil FROM usuario WHERE id_usuario = p_id_usuario;
    IF v_perfil IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário não encontrado.';
    END IF;
    IF v_perfil COLLATE utf8mb4_bin <> 'Coordenador' THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Apenas o Coordenador pode lançar notas.';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 204 | Busca o perfil do usuário que está tentando lançar. |
| 205 a 207 | Se ficou NULL, o usuário não existe: "Usuário não encontrado." |
| 208 a 211 | Se o perfil não é exatamente `'Coordenador'`, erro "Apenas o Coordenador pode lançar notas." Esta é a proteção **no banco**: mesmo que alguém chame a procedure direto, sem passar pela tela, o Secretário é barrado. |

### Matrícula existe, turma aberta e notas atuais (linhas 213 a 224)

```sql
    SELECT t.status, m.n1, m.n2
      INTO v_status_turma, v_n1_atual, v_n2_atual
      FROM matricula m
      JOIN turma t ON t.id_turma = m.id_turma
     WHERE m.id_matricula = p_id_matricula;
    IF v_status_turma IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Matrícula não encontrada.';
    END IF;
    IF v_status_turma COLLATE utf8mb4_bin <> 'Aberta' THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Turma encerrada: as notas não podem mais ser alteradas.';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 213 a 217 | Busca, ligando `matricula` com `turma`, o status da turma **e também** `m.n1` e `m.n2` (isso é novo: antes só vinha o status). Os três valores vão para `v_status_turma`, `v_n1_atual` e `v_n2_atual`. Uma consulta só serve para as duas checagens. |
| 218 a 220 | Se `v_status_turma` ficou NULL, a matrícula não existe: "Matrícula não encontrada." O status da turma é `NOT NULL`, então NULL só pode significar "não achou a linha". As notas atuais podem ser NULL de verdade (nota não lançada) e por isso não servem para essa conferência. |
| 221 a 224 | Se a turma não está `'Aberta'`, erro "Turma encerrada: as notas não podem mais ser alteradas." Depois que o semestre é fechado, as notas são definitivas. |

### Não apagar nota já lançada (linhas 226 a 230)

```sql
    IF (p_n1 IS NULL AND v_n1_atual IS NOT NULL)
       OR (p_n2 IS NULL AND v_n2_atual IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Não é possível apagar uma nota já lançada: informe o novo valor.';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 226 e 227 | Duas condições ligadas por `OR`. A primeira: o novo `p_n1` está em branco (NULL) **e** já existe um N1 gravado (`v_n1_atual IS NOT NULL`). A segunda: o mesmo para a N2. Se qualquer uma for verdadeira, a pessoa está tentando **apagar** uma nota. |
| 228 e 229 | Erro "Não é possível apagar uma nota já lançada: informe o novo valor." |
| 230 | Fecha o IF. |

Por que isso existe: o UPDATE da procedure grava `n1 = p_n1`, e se `p_n1` vier NULL, a nota antiga some. Um clique errado na tela, ou uma chamada direta com NULL, apagaria uma nota e mudaria a situação do aluno. Agora o banco recusa. O que **continua permitido**: lançar só a N1 numa matrícula que ainda não tem nota (o `v_n1_atual` é NULL, então não há nada a apagar) e **trocar** uma nota por outro valor, como corrigir 7,0 para 8,0. O NULL só é recusado quando há nota atual: NULL no lugar de NULL passa.

### Faltas e gravação (linhas 232 a 243)

```sql
    IF p_faltas IS NULL OR p_faltas < 0 THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Informe as faltas (zero ou mais).';
    END IF;

    UPDATE matricula
       SET n1         = p_n1,
           n2         = p_n2,
           faltas     = p_faltas,
           id_usuario = p_id_usuario
     WHERE id_matricula = p_id_matricula;
END$$
```

| Linha | O que faz |
|-------|-----------|
| 232 a 235 | As faltas são obrigatórias e não podem ser negativas: senão, erro "Informe as faltas (zero ou mais)." Isso é necessário porque a coluna `faltas` é `NOT NULL` e porque a situação depende delas. |
| 237 a 242 | `UPDATE` da matrícula: grava `n1`, `n2`, `faltas` e também o `id_usuario` de quem lançou. O `id_usuario` **no mesmo UPDATE** é importante: o trigger de auditoria tira daí o nome de quem mudou a nota. A procedure **não grava média nem situação**. O `trg_atualiza_situacao` (BEFORE UPDATE) recalcula as duas, e o `trg_auditoria_nota` (AFTER UPDATE) escreve no `log_nota`. |
| 243 | `END$$`. |

Se a nota for 11, o UPDATE é recusado pelo CHECK `ck_matricula_n1` (erro 3819) e nada é gravado.

## sp_lancar_exame (linhas 255 a 292)

> Resumo: grava a nota do exame, mas só quando a matrícula está "Em Exame". O resultado final (RN03) sai do `trg_atualiza_situacao`: média final de 5,0 ou mais vira "Aprovado", senão "Reprovado por Nota". Só o Coordenador pode.

### Parâmetros e variáveis (linhas 255 a 263)

```sql
CREATE PROCEDURE sp_lancar_exame(
    IN p_id_matricula  INT,
    IN p_exame         DECIMAL(4,2),
    IN p_id_usuario    INT
)
BEGIN
    DECLARE v_perfil    VARCHAR(11);
    DECLARE v_situacao  VARCHAR(19);
    DECLARE v_msg       VARCHAR(128);
```

| Linha | O que faz |
|-------|-----------|
| 255 a 259 | Recebe a matrícula, a nota do exame e o usuário. |
| 260 | `BEGIN`. |
| 261 a 263 | Variáveis: perfil, situação atual da matrícula e a mensagem de erro. |

### Só o Coordenador (linhas 265 a 272)

```sql
    SELECT perfil INTO v_perfil FROM usuario WHERE id_usuario = p_id_usuario;
    IF v_perfil IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário não encontrado.';
    END IF;
    IF v_perfil COLLATE utf8mb4_bin <> 'Coordenador' THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Apenas o Coordenador pode lançar exame.';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 265 a 268 | Busca o perfil; se NULL, "Usuário não encontrado." |
| 269 a 272 | Se não é `'Coordenador'`, "Apenas o Coordenador pode lançar exame." |

### A matrícula tem que estar "Em Exame" (linhas 274 a 282)

```sql
    SELECT situacao INTO v_situacao FROM matricula WHERE id_matricula = p_id_matricula;
    IF v_situacao IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Matrícula não encontrada.';
    END IF;
    IF v_situacao COLLATE utf8mb4_bin <> 'Em Exame' THEN
        SET v_msg = CONCAT('Exame só pode ser lançado para matrícula Em Exame; a situação atual é ',
                           v_situacao, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 274 | Busca a situação atual da matrícula. |
| 275 a 277 | Se NULL, a matrícula não existe: "Matrícula não encontrada." (a coluna `situacao` é `NOT NULL`). |
| 278 a 282 | Se a situação não é exatamente `'Em Exame'`, erro com a situação real: "Exame só pode ser lançado para matrícula Em Exame; a situação atual é Cursando." Isso impede lançar exame para quem já passou, já reprovou, ou ainda nem tem as duas notas. |

### Exame em branco e gravação (linhas 284 a 292)

```sql
    IF p_exame IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe a nota do exame.';
    END IF;

    UPDATE matricula
       SET exame      = p_exame,
           id_usuario = p_id_usuario
     WHERE id_matricula = p_id_matricula;
END$$
```

| Linha | O que faz |
|-------|-----------|
| 284 a 286 | Se o exame veio NULL, erro "Informe a nota do exame." |
| 288 a 291 | `UPDATE` que grava só o `exame` e o `id_usuario`. O trigger recalcula a média final como (média parcial + exame) / 2 e define se é Aprovado (5,0 ou mais) ou Reprovado por Nota. O trigger de auditoria registra o exame no log. |
| 292 | `END$$`. |

## sp_historico_aluno (linhas 301 a 312)

> Resumo: todas as matrículas do aluno, ordenadas por semestre e disciplina. Dá erro se o aluno não existe.

### Conferir o aluno (linhas 301 a 305)

```sql
CREATE PROCEDURE sp_historico_aluno(IN p_id_aluno INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM aluno WHERE id_aluno = p_id_aluno) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno não encontrado.';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 301 | Procedure com um parâmetro só (o `id_aluno`), na mesma linha. |
| 302 | `BEGIN`. |
| 303 a 305 | Se o aluno não existe: "Aluno não encontrado." Sem isso, um id errado devolveria uma tabela vazia, e ficaria igual a "aluno que ainda não cursou nada". |

### Consulta (linhas 307 a 312)

```sql
    SELECT semestre, disciplina, n1, n2, exame, media_final,
           faltas, frequencia, situacao
      FROM vw_boletim
     WHERE id_aluno = p_id_aluno
     ORDER BY semestre, disciplina;
END$$
```

| Linha | O que faz |
|-------|-----------|
| 307 e 308 | Escolhe as colunas do boletim, incluindo `frequencia`. Não tem `id_aluno` porque a tela já sabe de qual aluno é. |
| 309 | Lê da **view** `vw_boletim` do Diego, e não das tabelas. A procedure reaproveita o JOIN e a frequência que a view já faz. |
| 310 | Só as linhas do aluno pedido. |
| 311 | Ordena por semestre e, dentro dele, pela disciplina. |
| 312 | `END$$`. |

## sp_fechar_semestre (linhas 331 a 422)

> Resumo: encerra as turmas "Aberta" do semestre e fecha a situação de cada matrícula, **tudo ou nada**. "Em Exame" sem exame lançado vira "Reprovado por Nota". "Cursando" (falta N1 ou N2) faz o fechamento ser **recusado** e nada muda (ROLLBACK): é preciso lançar as notas antes. As demais situações já são definitivas. No fim devolve a contagem de matrículas do semestre por situação. As conferências de perfil e de formato vêm **antes** do START TRANSACTION, então um Secretário barrado não mexe em nada. Só o Coordenador pode.

### Parâmetros e variável (linhas 331 a 336)

```sql
CREATE PROCEDURE sp_fechar_semestre(
    IN p_semestre    CHAR(6),
    IN p_id_usuario  INT
)
BEGIN
    DECLARE v_perfil VARCHAR(11);
```

| Linha | O que faz |
|-------|-----------|
| 331 a 334 | Recebe o semestre (`CHAR(6)`, no formato `2026.2`) e o usuário. |
| 335 | `BEGIN` (bloco externo). |
| 336 | Variável do perfil. |

### Conferências antes da transação (linhas 338 a 349)

```sql
    SELECT perfil INTO v_perfil FROM usuario WHERE id_usuario = p_id_usuario;
    IF v_perfil IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário não encontrado.';
    END IF;
    IF v_perfil COLLATE utf8mb4_bin <> 'Coordenador' THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Apenas o Coordenador pode fechar o semestre.';
    END IF;
    IF p_semestre IS NULL OR NOT REGEXP_LIKE(p_semestre, '^[0-9]{4}[.][12]$') THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Semestre inválido: use o formato AAAA.S, por exemplo 2026.2.';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 338 a 341 | Busca o perfil; se NULL, "Usuário não encontrado." |
| 342 a 345 | Se não é `'Coordenador'`, "Apenas o Coordenador pode fechar o semestre." |
| 346 a 349 | Se o semestre é NULL ou **não bate** com o padrão `AAAA.S` (quatro dígitos, ponto, 1 ou 2), erro "Semestre inválido: use o formato AAAA.S, por exemplo 2026.2." Isso evita fechar um semestre por engano de digitação. |

Tudo isso vem **antes** do `START TRANSACTION`. Assim, um Secretário que tenta fechar o semestre é barrado sem abrir transação alguma e sem mexer em nada, e o ROLLBACK do handler (mais abaixo) nunca desfaz trabalho de outra pessoa.

### Bloco interno e variáveis (linhas 351 a 357)

```sql
    BEGIN
        DECLARE v_fim           INT DEFAULT 0;
        DECLARE v_abertas       INT;
        DECLARE v_id_matricula  INT;
        DECLARE v_situacao      VARCHAR(19);
        DECLARE v_aluno         VARCHAR(100);
        DECLARE v_msg           VARCHAR(128);
```

| Linha | O que faz |
|-------|-----------|
| 351 | `BEGIN` de um **bloco interno**. Por quê: no MySQL, as declarações de cursor e handler precisam vir no começo de um bloco, antes de qualquer comando. Como o bloco externo já executou SELECTs e IFs, abrimos um novo. |
| 352 | `v_fim`: uma bandeirinha que começa em 0 e vira 1 quando o cursor acaba. |
| 353 | `v_abertas`: quantas turmas abertas há no semestre. |
| 354 a 356 | Onde o cursor vai guardar, a cada passo: o id da matrícula, a situação e o nome do aluno. |
| 357 | A mensagem de erro. |

### Declaração do cursor (linhas 359 a 367)

```sql
        DECLARE cur_matriculas CURSOR FOR
            SELECT m.id_matricula, m.situacao, a.nome
              FROM matricula m
              JOIN turma t ON t.id_turma = m.id_turma
              JOIN aluno a ON a.id_aluno = m.id_aluno
             WHERE t.semestre = p_semestre
               AND t.status   = 'Aberta'
               AND m.situacao IN ('Cursando', 'Em Exame')
             ORDER BY m.id_matricula;
```

| Linha | O que faz |
|-------|-----------|
| 359 | `DECLARE cur_matriculas CURSOR FOR`: declara um cursor com este SELECT. Ainda não executa nada. |
| 360 | O que o cursor devolve a cada linha: id da matrícula, situação e nome do aluno. |
| 361 a 363 | Liga matrícula, turma e aluno. |
| 364 e 365 | Só as turmas do semestre pedido que ainda estão `'Aberta'`. |
| 366 | Só as matrículas "Cursando" ou "Em Exame", que são as únicas que precisam de atenção no fechamento. |
| 367 | Ordenadas pelo id, para o percurso ser previsível. |

### Handlers (linhas 369 a 374)

```sql
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim = 1;
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;
```

| Linha | O que faz |
|-------|-----------|
| 369 | `CONTINUE HANDLER FOR NOT FOUND SET v_fim = 1`: quando o FETCH não encontra mais linhas, ele liga a bandeirinha `v_fim` e o programa **continua** de onde estava. É assim que o laço sabe a hora de parar. |
| 370 a 374 | `EXIT HANDLER FOR SQLEXCEPTION`: se **qualquer erro** acontecer dentro deste bloco (inclusive os SIGNAL que nós mesmos lançamos), ele roda `ROLLBACK` (desfaz tudo da transação) e depois `RESIGNAL` (relança o mesmo erro para quem chamou). Sem o RESIGNAL, o erro seria engolido: a procedure terminaria sem avisar nada, como se tivesse dado certo. |

### Abrir a transação e travar as turmas (linhas 376 a 387)

```sql
        START TRANSACTION;

        SELECT COUNT(*)
          INTO v_abertas
          FROM turma
         WHERE semestre = p_semestre
           AND status   = 'Aberta'
           FOR UPDATE;
        IF v_abertas = 0 THEN
            SIGNAL SQLSTATE '45000'
               SET MESSAGE_TEXT = 'Não há turma aberta neste semestre.';
        END IF;
```

| Linha | O que faz |
|-------|-----------|
| 376 | `START TRANSACTION`: começa o pacote "tudo ou nada". |
| 378 a 383 | Conta as turmas abertas do semestre. O `FOR UPDATE` **trava** essas turmas até o fim da transação, para ninguém mudar o status delas enquanto fechamos. |
| 384 a 387 | Se não há nenhuma turma aberta (ou o semestre nem existe), erro "Não há turma aberta neste semestre." O handler dá ROLLBACK e relança. É também o que acontece se alguém tentar fechar o mesmo semestre duas vezes. |

### Abrir o cursor e ler a primeira linha (linhas 389 a 394)

```sql
        OPEN cur_matriculas;
        ler: LOOP
            FETCH cur_matriculas INTO v_id_matricula, v_situacao, v_aluno;
            IF v_fim = 1 THEN
                LEAVE ler;
            END IF;
```

| Linha | O que faz |
|-------|-----------|
| 389 | `OPEN` executa o SELECT do cursor. |
| 390 | `ler: LOOP` começa um laço com o nome (rótulo) `ler`. |
| 391 | `FETCH ... INTO`: traz a próxima linha do cursor para as três variáveis. |
| 392 a 394 | Se `v_fim` virou 1 (acabaram as linhas), `LEAVE ler` sai do laço. |

### Cursando: recusar tudo (linhas 396 a 400)

```sql
            IF v_situacao = 'Cursando' THEN
                SET v_msg = CONCAT('Matrícula ', v_id_matricula, ' (', v_aluno,
                                   ') sem N1 ou N2: lance as notas antes de fechar o semestre.');
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
            END IF;
```

| Linha | O que faz |
|-------|-----------|
| 396 | Se a matrícula está "Cursando", falta N1 ou N2. |
| 397 a 399 | Monta a mensagem apontando a matrícula e o aluno ("Matrícula 17 (Alice Monteiro) sem N1 ou N2: lance as notas antes de fechar o semestre.") e lança o erro. O handler faz **ROLLBACK de tudo**, inclusive dos "Em Exame" que já tinham sido alterados antes de chegar nessa linha. |

### Em Exame sem exame vira reprovado (linhas 402 a 407)

```sql
            UPDATE matricula
               SET situacao   = 'Reprovado por Nota',
                   id_usuario = p_id_usuario
             WHERE id_matricula = v_id_matricula;
        END LOOP;
        CLOSE cur_matriculas;
```

| Linha | O que faz |
|-------|-----------|
| 402 a 405 | Se chegou aqui, a matrícula está "Em Exame" (e o exame não foi lançado, senão ela já teria virado Aprovado ou Reprovado). Grava a situação `'Reprovado por Nota'` e o `id_usuario` de quem fechou. O UPDATE mexe **só na situação**; por isso o `trg_atualiza_situacao` não recalcula e respeita o valor. |
| 406 | `END LOOP` volta para o `LOOP` e busca a próxima linha. |
| 407 | `CLOSE` libera o cursor quando o laço termina. |

### Encerrar as turmas e confirmar (linhas 409 a 415)

```sql
        UPDATE turma
           SET status = 'Encerrada'
         WHERE semestre = p_semestre
           AND status   = 'Aberta';

        COMMIT;
    END;
```

| Linha | O que faz |
|-------|-----------|
| 409 a 412 | Passa o status das turmas abertas do semestre para `'Encerrada'`. Daí em diante, ninguém mais se matricula nem lança nota nelas. |
| 414 | `COMMIT`: confirma tudo de uma vez (as situações e o encerramento das turmas). |
| 415 | `END;` fecha o bloco interno. |

### Resumo final (linhas 417 a 422)

```sql
    SELECT situacao, COUNT(*) AS total
      FROM vw_boletim
     WHERE semestre = p_semestre
     GROUP BY situacao
     ORDER BY situacao;
END$$
```

| Linha | O que faz |
|-------|-----------|
| 417 a 421 | Devolve uma tabela com quantas matrículas do semestre há em cada situação (por exemplo "Aprovado 2" e "Reprovado por Nota 1"), lendo da `vw_boletim`. |
| 422 | `END$$`. |

### Volta do delimitador (linha 424)

```sql
DELIMITER ;
```

| Linha | O que faz |
|-------|-----------|
| 424 | `DELIMITER ;` devolve o terminador normal. |

## PARTE B: o arquivo 04_testes.sql

## Cabeçalho (linhas 1 a 34)

> O cabeçalho explica como usar: rode o arquivo inteiro. Não precisa desligar o "parar no erro" do Workbench, porque os testes que **devem falhar** rodam por dentro da `sp_teste_erro`, que captura o erro e só registra a mensagem. No final aparece uma tabela com teste, esperado, obtido e resultado (OK ou FALHOU), que é a evidência para o relatório. O script **não suja a massa de dados**: os testes 1 a 10 e 12 rodam numa transação que termina em ROLLBACK, e o teste 11 apaga o que criou (só os contadores de AUTO_INCREMENT avançam). As procedures auxiliares são apagadas no fim. Os testes são: 1 login; 2 turma lotada; 3 sem pré-requisito; 4 aluno Trancado e Formado; 5 nota fora do intervalo; 6 notas, exame e situação final; 7 média 9,0 com frequência abaixo de 75%; 8 auditoria; 9 as 3 views; 10 Secretário fechando o semestre (extra); 11 fechamento de semestre com sucesso e com ROLLBACK (extra); 12 matrícula em disciplina já aprovada e nota já lançada que não se apaga (extra).

## Preparação (linhas 36 a 55)

### USE (linha 36)

```sql
USE sga_fbi;
```

| Linha | O que faz |
|-------|-----------|
| 36 | Escolhe o banco `sga_fbi`. |

### Tabela de resultados (linhas 43 a 50)

```sql
DROP TEMPORARY TABLE IF EXISTS teste_resultado;
CREATE TEMPORARY TABLE teste_resultado (
    ordem      INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    teste      VARCHAR(70)  NOT NULL,
    esperado   VARCHAR(150) NOT NULL,
    obtido     VARCHAR(255) NULL,
    resultado  VARCHAR(6)   NOT NULL
) ENGINE = MEMORY;
```

| Linha | O que faz |
|-------|-----------|
| 43 | Apaga a tabela temporária de uma execução anterior, se existir. |
| 44 a 49 | Cria a tabela `teste_resultado` com: ordem (número automático), nome do teste, o que se esperava, o que foi obtido e o resultado (`OK` ou `FALHOU`, no máximo 6 letras). É `TEMPORARY`: só existe nesta conexão e some sozinha. |
| 50 | `ENGINE = MEMORY`: a tabela fica na memória e **não é transacional**. Por quê: os testes 1 a 10 e 12 terminam com `ROLLBACK`. Se a tabela de resultados fosse comum, o ROLLBACK apagaria também os resultados já registrados. Na MEMORY, o ROLLBACK não encosta nela. (Por isso só há colunas VARCHAR: a MEMORY não aceita TEXT.) |

### Apagar procedures antigas e trocar o delimitador (linhas 52 a 55)

```sql
DROP PROCEDURE IF EXISTS sp_teste_erro;
DROP PROCEDURE IF EXISTS sp_teste_igual;

DELIMITER $$
```

| Linha | O que faz |
|-------|-----------|
| 52 e 53 | Apaga as duas procedures auxiliares dos testes, se existirem. |
| 55 | `DELIMITER $$` para poder criá-las. |

## sp_teste_erro (linhas 59 a 81)

> Resumo: executa um comando que **deve falhar** e confere se a mensagem de erro contém o trecho esperado.

### Parâmetros (linhas 59 a 65)

```sql
CREATE PROCEDURE sp_teste_erro(
    IN p_teste     VARCHAR(70),
    IN p_comando   TEXT,
    IN p_esperado  VARCHAR(150)
)
BEGIN
    DECLARE v_msg TEXT DEFAULT NULL;
```

| Linha | O que faz |
|-------|-----------|
| 59 a 63 | Recebe três parâmetros: o nome do teste, o **comando como texto** (por exemplo `'CALL sp_matricular_aluno(5, 3, 3)'`) e o trecho de mensagem que se espera. |
| 65 | `v_msg` começa NULL e guardará a mensagem de erro, se houver. |

### Capturar o erro (linhas 67 a 70)

```sql
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
    END;
```

| Linha | O que faz |
|-------|-----------|
| 67 | `CONTINUE HANDLER FOR SQLEXCEPTION`: se qualquer erro acontecer, em vez de interromper o script, executa o bloco abaixo e **continua**. |
| 69 | `GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT`: lê a mensagem do erro que acabou de acontecer e guarda em `v_msg`. |

### Executar o comando (linhas 72 a 75)

```sql
    SET @sql_teste = p_comando;
    PREPARE stmt_teste FROM @sql_teste;
    EXECUTE stmt_teste;
    DEALLOCATE PREPARE stmt_teste;
```

| Linha | O que faz |
|-------|-----------|
| 72 | Guarda o texto do comando numa variável de usuário `@sql_teste`. O `PREPARE` exige um texto literal ou uma variável com `@`, não aceita variável local. |
| 73 | `PREPARE` transforma o texto em um comando pronto para executar. |
| 74 | `EXECUTE` roda o comando. Se ele falhar, o handler captura a mensagem e o programa segue para a linha 75. |
| 75 | `DEALLOCATE PREPARE` libera o comando preparado. |

### Registrar o resultado (linhas 77 a 81)

```sql
    INSERT INTO teste_resultado (teste, esperado, obtido, resultado)
    VALUES (p_teste, p_esperado,
            COALESCE(v_msg, 'o comando NÃO falhou'),
            IF(v_msg LIKE CONCAT('%', p_esperado, '%'), 'OK', 'FALHOU'));
END$$
```

| Linha | O que faz |
|-------|-----------|
| 77 e 78 | Insere uma linha na tabela de resultados com o nome do teste e o que se esperava. |
| 79 | Em "obtido" vai a mensagem de erro, ou o texto 'o comando NÃO falhou' se `v_msg` ficou NULL. |
| 80 | `IF(v_msg LIKE CONCAT('%', p_esperado, '%'), 'OK', 'FALHOU')`: se a mensagem **contém** o trecho esperado, `OK`; senão `FALHOU`. Se o comando não falhou, `v_msg` é NULL, o LIKE dá NULL (que o IF trata como falso) e o resultado é `FALHOU`, o que está certo: era para ter falhado. |
| 81 | `END$$`. |

## sp_teste_igual (linhas 84 a 93)

> Resumo: compara dois valores como texto (NULL só é igual a NULL).

### Parâmetros (linhas 84 a 89)

```sql
CREATE PROCEDURE sp_teste_igual(
    IN p_teste     VARCHAR(70),
    IN p_esperado  VARCHAR(150),
    IN p_obtido    VARCHAR(255)
)
BEGIN
```

| Linha | O que faz |
|-------|-----------|
| 84 a 88 | Recebe o nome do teste, o valor esperado e o valor obtido, os dois como texto. |
| 89 | `BEGIN`. |

### Comparação (linhas 90 a 93)

```sql
    INSERT INTO teste_resultado (teste, esperado, obtido, resultado)
    VALUES (p_teste, COALESCE(p_esperado, 'NULL'), COALESCE(p_obtido, 'NULL'),
            IF(p_esperado <=> p_obtido, 'OK', 'FALHOU'));
END$$
```

| Linha | O que faz |
|-------|-----------|
| 90 a 92 | Insere uma linha na tabela de resultados. `COALESCE(..., 'NULL')` troca NULL pelo texto 'NULL' para aparecer na tabela. `IF(p_esperado <=> p_obtido, 'OK', 'FALHOU')`: o `<=>` compara tratando NULL como valor (NULL é igual a NULL e diferente de qualquer número), e o resultado é `OK` ou `FALHOU`. |
| 93 | `END$$`. |

### Volta do delimitador e início da transação (linhas 95 a 97)

```sql
DELIMITER ;

START TRANSACTION;
```

| Linha | O que faz |
|-------|-----------|
| 95 | `DELIMITER ;` volta ao normal. |
| 97 | `START TRANSACTION;` abre a transação em que rodam os testes 1 a 10 e 12. Foi **depois** de criar as procedures porque `CREATE PROCEDURE` faz commit implícito e fecharia a transação. Tudo que os testes 1 a 10 e 12 gravarem será desfeito no `ROLLBACK` da linha 276. |

## Teste 1: login com senha incorreta e usuário inexistente (linhas 104 a 111)

- **Cenário:** três chamadas da `sp_LoginUsuario`: senha errada, usuário que não existe, e a senha certa.
- **Esperado:** as duas primeiras devolvem resultado **vazio**; a terceira devolve uma linha (id, nome, e-mail, perfil), sem a senha.
- **O que acontece:** exatamente isso: vazio, vazio, e uma linha da Ana Beatriz Moura, Coordenador.
- **Por que importa:** mostra que o login funciona e que quem erra não entra, e que o sistema não revela se foi o login ou a senha que errou.

```sql
SELECT 'T1a: senha incorreta (esperado: vazio)' AS teste;
CALL sp_LoginUsuario('coord.ana', SHA2('senhaErrada', 256));

SELECT 'T1b: usuário inexistente (esperado: vazio)' AS teste;
CALL sp_LoginUsuario('ninguem', SHA2('Senha@123', 256));

SELECT 'T1c: senha correta (esperado: 1 linha, perfil Coordenador)' AS teste;
CALL sp_LoginUsuario('coord.ana', SHA2('Senha@123', 256));
```

| Linha | O que faz |
|-------|-----------|
| 104, 107, 110 | Um `SELECT 'texto' AS teste` antes de cada chamada, só para aparecer o rótulo no resultado do Workbench e dar para saber qual tabela é de qual teste. |
| 105 | Login correto com a **senha errada**: `SHA2('senhaErrada', 256)` gera o hash do texto errado. Resultado vazio. |
| 108 | Login que não existe (`ninguem`) com a senha certa. Resultado vazio. |
| 111 | Login e senha certos (`Senha@123`). Devolve uma linha. |

Note que o teste usa `SHA2(...)` dentro do próprio SQL para gerar o hash. Na aplicação, quem calcula o hash é o Java, antes de chamar a procedure.

## Teste 2: matrícula em turma lotada, RN05 (linhas 118 a 120)

- **Cenário:** a turma 3 (POO) tem 4 vagas e 4 matriculados. O aluno 5 está Ativo e foi aprovado em Lógica (o pré-requisito de POO), então só a falta de vaga pode barrá-lo.
- **Esperado:** erro contendo "Turma lotada".
- **O que acontece:** "Turma lotada: a turma 3 já tem 4 de 4 vagas ocupadas." A mensagem vem do `trg_valida_vagas` do Diego.
- **Por que importa:** prova a RN05 e mostra que o cenário foi montado para falhar **só** por um motivo (se o aluno também não tivesse o pré-requisito, o teste não provaria nada sobre vagas).

```sql
CALL sp_teste_erro('T2: matrícula em turma lotada',
    'CALL sp_matricular_aluno(5, 3, 3)',
    'Turma lotada');
```

| Linha | O que faz |
|-------|-----------|
| 118 | Chama `sp_teste_erro` com o nome do teste. |
| 119 | O comando que deve falhar, escrito como texto: matricular o aluno 5, na turma 3, pelo usuário 3 (a Secretária Carla). |
| 120 | O trecho que a mensagem de erro deve conter: `'Turma lotada'`. |

## Teste 3: matrícula sem pré-requisito, RN06 (linhas 127 a 129)

- **Cenário:** a turma 5 (Estruturas de Dados) exige Algoritmos. O aluno 16 foi "Reprovado por Nota" em Algoritmos, e a turma 5 tem vagas (6 de 8).
- **Esperado:** erro contendo "Falta pré-requisito".
- **O que acontece:** "Falta pré-requisito: o aluno não foi aprovado em Algoritmos."
- **Por que importa:** prova a RN06 e que reprovar **não** conta como cumprir o pré-requisito. Só "Aprovado" vale.

```sql
CALL sp_teste_erro('T3: matrícula sem pré-requisito',
    'CALL sp_matricular_aluno(16, 5, 3)',
    'Falta pré-requisito');
```

| Linha | O que faz |
|-------|-----------|
| 127 a 129 | Mesmo formato: o comando `CALL sp_matricular_aluno(16, 5, 3)` e o trecho esperado `'Falta pré-requisito'`. |

## Teste 4: aluno Trancado ou Formado, RN09 (linhas 134 a 139)

- **Cenário:** o aluno 19 está Trancado e o 20 está Formado, ambos tentando entrar na turma 4 (Banco de Dados), que tem vaga e não tem pré-requisito.
- **Esperado:** dois erros, um contendo "Trancado" e outro "Formado".
- **O que acontece:** "Aluno Trancado não pode se matricular: só alunos Ativos." e a mesma frase com "Formado".
- **Por que importa:** prova a RN09 e que a mensagem mostra o status real do aluno.

```sql
CALL sp_teste_erro('T4a: matrícula de aluno Trancado',
    'CALL sp_matricular_aluno(19, 4, 3)',
    'Trancado');
CALL sp_teste_erro('T4b: matrícula de aluno Formado',
    'CALL sp_matricular_aluno(20, 4, 3)',
    'Formado');
```

| Linha | O que faz |
|-------|-----------|
| 134 a 136 | Teste 4a: matricular o aluno 19 na turma 4; espera-se a palavra `'Trancado'` na mensagem. |
| 137 a 139 | Teste 4b: o mesmo com o aluno 20; espera-se `'Formado'`. |

## Teste 5: nota fora do intervalo, RN07 (linhas 144 a 149)

- **Cenário:** lançar N1 = 11,0 e, em outro comando, N2 = -1,0 na matrícula 20.
- **Esperado:** o erro do CHECK, citando `ck_matricula_n1` e `ck_matricula_n2`.
- **O que acontece:** "Check constraint 'ck_matricula_n1' is violated." (e `ck_matricula_n2`).
- **Por que importa:** prova que a regra de 0 a 10 está **no banco** (CHECK do DDL), e não depende de a procedure ou da tela lembrar de validar. Repare que o erro **não** é um SIGNAL 45000: é o erro 3819 do próprio CHECK.

```sql
CALL sp_teste_erro('T5a: N1 = 11,0 barrada pelo CHECK',
    'CALL sp_lancar_notas(20, 11.0, 5.0, 0, 1)',
    'ck_matricula_n1');
CALL sp_teste_erro('T5b: N2 = -1,0 barrada pelo CHECK',
    'CALL sp_lancar_notas(20, 5.0, -1.0, 0, 1)',
    'ck_matricula_n2');
```

| Linha | O que faz |
|-------|-----------|
| 144 a 146 | Teste 5a: `sp_lancar_notas(20, 11.0, 5.0, 0, 1)`, ou seja, matrícula 20, N1 11, N2 5, 0 faltas, usuário 1 (Coordenadora Ana). Espera-se o nome da constraint, `ck_matricula_n1`. |
| 147 a 149 | Teste 5b: N2 = -1,0, e espera-se `ck_matricula_n2`. |

## Teste 6: notas, Em Exame, exame, situação final, RN02 e RN03 (linhas 155 a 179)

Este é o teste mais completo da parte acadêmica. Ele tem várias etapas.

### Etapa 6a: a situação inicial (linha 155 e 156)

- **Cenário:** a matrícula 18 (aluno 2, turma 3) tem N1 = 6,0 e N2 = 7,0, parcial 6,5.
- **Esperado:** "Em Exame". **Acontece:** "Em Exame" (parcial entre 4,00 e 6,99).

```sql
SELECT situacao INTO @situacao_antes FROM matricula WHERE id_matricula = 18;
CALL sp_teste_igual('T6a: N1 6,0 e N2 7,0 caem em', 'Em Exame', @situacao_antes);
```

| Linha | O que faz |
|-------|-----------|
| 155 | Busca a situação da matrícula 18 e guarda na variável `@situacao_antes`. |
| 156 | `sp_teste_igual` compara o esperado `'Em Exame'` com o obtido. |

### Etapas 6b e 6c: exame que não pode ser lançado (linhas 158 a 164)

- **6b:** exame para a matrícula 17, que está "Cursando" (falta N2). **Esperado:** erro "Exame só pode ser lançado...". **Acontece:** "Exame só pode ser lançado para matrícula Em Exame; a situação atual é Cursando."
- **6c:** a Secretária Carla (usuário 3) tenta lançar exame na matrícula 18, que **está** Em Exame. **Esperado:** "Apenas o Coordenador". **Acontece:** "Apenas o Coordenador pode lançar exame."
- **Por que importam:** 6b prova que só se lança exame para quem está "Em Exame". 6c prova a regra de perfil: a matrícula estava correta, então o que barrou foi só o perfil.

```sql
CALL sp_teste_erro('T6b: exame de quem NÃO está Em Exame',
    'CALL sp_lancar_exame(17, 5.0, 1)',
    'Exame só pode ser lançado');

CALL sp_teste_erro('T6c: Secretário não lança exame',
    'CALL sp_lancar_exame(18, 5.0, 3)',
    'Apenas o Coordenador');
```

| Linha | O que faz |
|-------|-----------|
| 158 a 160 | 6b: `sp_lancar_exame(17, 5.0, 1)`, matrícula 17, exame 5,0, usuário Coordenador. Espera-se `'Exame só pode ser lançado'`. |
| 162 a 164 | 6c: `sp_lancar_exame(18, 5.0, 3)`, agora com o usuário 3 (Secretário). Espera-se `'Apenas o Coordenador'`. |

### Etapas 6d e 6e: exame que aprova (linhas 166 a 170)

- **Cenário:** o Coordenador lança exame 5,0 na matrícula 18 (parcial 6,5).
- **Esperado:** média final (6,5 + 5,0) / 2 = **5,75** e situação "Aprovado" (5,75 é pelo menos 5,0).
- **O que acontece:** 5.75 e Aprovado.

```sql
CALL sp_lancar_exame(18, 5.0, 1);
SELECT media_final, situacao INTO @media_exame, @situacao_exame
  FROM matricula WHERE id_matricula = 18;
CALL sp_teste_igual('T6d: média final com exame 5,0 = (6,5 + 5,0) / 2', '5.75', @media_exame);
CALL sp_teste_igual('T6e: situação final com média 5,75', 'Aprovado', @situacao_exame);
```

| Linha | O que faz |
|-------|-----------|
| 166 | Lança o exame de verdade, com o usuário 1 (Coordenador). Sem `sp_teste_erro`, porque aqui **não** deve falhar. |
| 167 e 168 | Lê `media_final` e `situacao` da matrícula e guarda nas variáveis `@media_exame` e `@situacao_exame`. |
| 169 | Confere a média: esperado `'5.75'`. |
| 170 | Confere a situação: esperado `'Aprovado'`. |

### Etapas 6f, 6g e 6h: exame que reprova (linhas 172 a 179)

- **Cenário:** matrícula 24 (aluno 4, turma 4): N1 = 5,0 e N2 = 6,0, parcial 5,5, que está Em Exame. O Coordenador lança exame 2,0.
- **Esperado:** média final (5,5 + 2,0) / 2 = **3,75** e situação "Reprovado por Nota".
- **O que acontece:** 3.75 e Reprovado por Nota.
- **Por que importa:** com 6d e 6e, cobre os dois caminhos do exame (aprova e reprova) e o limite de 5,0 da RN03.

```sql
-- Exame reprovando: matrícula 24 (aluno 4, turma 4): 5,0 e 6,0, parcial 5,5.
SELECT situacao INTO @situacao_antes FROM matricula WHERE id_matricula = 24;
CALL sp_teste_igual('T6f: N1 5,0 e N2 6,0 caem em', 'Em Exame', @situacao_antes);
CALL sp_lancar_exame(24, 2.0, 1);
SELECT media_final, situacao INTO @media_exame, @situacao_exame
  FROM matricula WHERE id_matricula = 24;
CALL sp_teste_igual('T6g: média final com exame 2,0 = (5,5 + 2,0) / 2', '3.75', @media_exame);
CALL sp_teste_igual('T6h: situação final com média 3,75', 'Reprovado por Nota', @situacao_exame);
```

| Linha | O que faz |
|-------|-----------|
| 172 | Comentário que descreve o cenário. |
| 173 e 174 | Confere que a matrícula 24 começa "Em Exame". |
| 175 | Lança o exame 2,0. |
| 176 e 177 | Lê a média e a situação resultantes. |
| 178 | Confere a média: `'3.75'`. |
| 179 | Confere a situação: `'Reprovado por Nota'`. |

## Teste 7: média 9,0 com frequência abaixo de 75%, RN04 (linhas 186 a 194)

- **Cenário:** a matrícula 17 (aluno 1, turma 3, 80 aulas) recebe N1 = 9,0, N2 = 9,0 e 25 faltas. A presença é (80 − 25) / 80 = 68,75%.
- **Esperado:** média 9,00, frequência 68,75 e situação "Reprovado por Falta".
- **O que acontece:** exatamente isso. A segunda parte (7d) confere que a matrícula 19 da massa de dados (9,5 e 9,5 com 25 faltas) também está "Reprovado por Falta".
- **Por que importa:** é o teste "armadilha" do enunciado: nota excelente **e** reprovado. Prova que a frequência vem antes da nota (RN04).

```sql
CALL sp_lancar_notas(17, 9.0, 9.0, 25, 1);
SELECT media_final, frequencia, situacao INTO @media_t7, @freq_t7, @situacao_t7
  FROM vw_boletim WHERE id_matricula = 17;
CALL sp_teste_igual('T7a: média final', '9.00', @media_t7);
CALL sp_teste_igual('T7b: frequência (%)', '68.75', @freq_t7);
CALL sp_teste_igual('T7c: situação com média 9,0 e 68,75% de presença', 'Reprovado por Falta', @situacao_t7);
```

| Linha | O que faz |
|-------|-----------|
| 186 | Lança N1 9,0, N2 9,0 e 25 faltas na matrícula 17. |
| 187 e 188 | Lê média, frequência e situação, desta vez pela `vw_boletim` (que calcula a frequência). |
| 189 | Confere a média: `'9.00'`. |
| 190 | Confere a frequência: `'68.75'`. |
| 191 | Confere a situação: `'Reprovado por Falta'`. |

```sql
SELECT situacao INTO @situacao_t7 FROM matricula WHERE id_matricula = 19;
CALL sp_teste_igual('T7d: cenário da massa (matrícula 19, 9,5 e 9,5)', 'Reprovado por Falta', @situacao_t7);
```

| Linha | O que faz |
|-------|-----------|
| 193 | Lê a situação da matrícula 19, que já veio assim da massa de dados. |
| 194 | Confere que é `'Reprovado por Falta'`. Prova que o trigger calcula certo já na inserção (`trg_situacao_inicial`). |

## Teste 8: alteração de notas gera log_nota, RN08 (linhas 202 a 215)

- **Cenário:** a matrícula 20 (aluno 4, turma 3) começa sem nota alguma. O Coordenador lança N1 = 7,0, N2 = 8,0 e 0 faltas.
- **Esperado:** **2** linhas novas no `log_nota`: uma para `n1` (NULL para 7,00) e uma para `n2` (NULL para 8,00), com o usuário 1. As faltas não mudaram (0 para 0), então não geram linha.
- **O que acontece:** 2 linhas, usuário 1.
- **Por que importa:** prova a auditoria (RN08), que o primeiro lançamento (de NULL) é registrado, e que o usuário do log é o de quem lançou.

```sql
SELECT COUNT(*) INTO @log_antes FROM log_nota WHERE id_matricula = 20;
CALL sp_lancar_notas(20, 7.0, 8.0, 0, 1);
SELECT COUNT(*), MIN(usuario), SUM(campo = 'n1' AND valor_antigo IS NULL AND valor_novo = 7.00),
       SUM(campo = 'n2' AND valor_antigo IS NULL AND valor_novo = 8.00)
  INTO @log_novas, @log_usuario, @log_n1, @log_n2
  FROM log_nota WHERE id_matricula = 20;
CALL sp_teste_igual('T8a: linhas novas no log_nota', '2', @log_novas - @log_antes);
CALL sp_teste_igual('T8b: log do n1 (NULL -> 7,00)', '1', @log_n1);
CALL sp_teste_igual('T8c: log do n2 (NULL -> 8,00)', '1', @log_n2);
CALL sp_teste_igual('T8d: usuário gravado no log (sp_lancar_notas, id 1)', '1', @log_usuario);
```

| Linha | O que faz |
|-------|-----------|
| 202 | Conta quantas linhas de log a matrícula 20 já tem, antes (deve ser 0). |
| 203 | Lança as notas. |
| 204 e 205 | Em uma consulta só: quantas linhas de log tem agora; o menor `usuario` (todas devem ser o 1); e, usando `SUM` de uma comparação (que vale 1 ou 0), quantas linhas são do campo `n1` com valor antigo NULL e valor novo 7,00, e do campo `n2`, 8,00. |
| 206 e 207 | `INTO` guarda os resultados em variáveis; a consulta lê só os logs da matrícula 20. |
| 208 | 8a: o número de linhas novas (agora menos antes) deve ser `'2'`. |
| 209 | 8b: existe exatamente 1 log do n1 com NULL para 7,00. |
| 210 | 8c: existe exatamente 1 log do n2 com NULL para 8,00. |
| 211 | 8d: o usuário gravado no log é o `'1'`. |

```sql
SELECT 'T8: log_nota da matrícula 20' AS teste;
SELECT id_log, id_matricula, campo, valor_antigo, valor_novo, usuario, data_hora
  FROM log_nota WHERE id_matricula = 20 ORDER BY id_log;
```

| Linha | O que faz |
|-------|-----------|
| 213 a 215 | Mostra as linhas do log da matrícula 20 na tela, como evidência visual para o relatório. |

## Teste 9: as 3 views (linhas 220 a 232)

- **Cenário:** consultar `vw_boletim`, `vw_turmas_lotacao` e `vw_desempenho_turma`.
- **Esperado:** 35 linhas na primeira (uma por matrícula) e 5 em cada uma das outras duas (uma por turma).
- **O que acontece:** 35, 5 e 5, e as consultas completas aparecem na tela.
- **Por que importa:** prova que as views existem, funcionam e devolvem a quantidade certa de linhas. O enunciado pede a execução e consulta das 3 views.

```sql
SELECT COUNT(*) INTO @n_boletim FROM vw_boletim;
SELECT COUNT(*) INTO @n_lotacao FROM vw_turmas_lotacao;
SELECT COUNT(*) INTO @n_desempenho FROM vw_desempenho_turma;
CALL sp_teste_igual('T9a: vw_boletim (1 linha por matrícula)', '35', @n_boletim);
CALL sp_teste_igual('T9b: vw_turmas_lotacao (1 linha por turma)', '5', @n_lotacao);
CALL sp_teste_igual('T9c: vw_desempenho_turma (1 linha por turma)', '5', @n_desempenho);
```

| Linha | O que faz |
|-------|-----------|
| 220 a 222 | Conta as linhas de cada view e guarda em variáveis. |
| 223 a 225 | Confere as contagens: `'35'`, `'5'` e `'5'`. |

```sql
SELECT 'T9a: vw_boletim (aluno 1)' AS teste;
SELECT * FROM vw_boletim WHERE id_aluno = 1 ORDER BY semestre;
SELECT 'T9b: vw_turmas_lotacao' AS teste;
SELECT * FROM vw_turmas_lotacao ORDER BY id_turma;
SELECT 'T9c: vw_desempenho_turma' AS teste;
SELECT * FROM vw_desempenho_turma ORDER BY id_turma;
```

| Linha | O que faz |
|-------|-----------|
| 227 a 232 | Mostra o conteúdo das views: o boletim do aluno 1, todas as turmas com lotação e o desempenho de todas as turmas. Cada uma tem um `SELECT` de rótulo antes, para identificar a tabela. |

## Teste 10 (extra): Secretário tentando fechar o semestre (linhas 234 a 239)

- **Cenário:** o usuário 3 (Secretária Carla) tenta `sp_fechar_semestre('2026.2', 3)`.
- **Esperado:** erro "Apenas o Coordenador".
- **O que acontece:** "Apenas o Coordenador pode fechar o semestre."
- **Por que importa:** prova o controle de perfil **no banco**. O Secretário não tem acesso a fechamento de turmas.

```sql
CALL sp_teste_erro('T10: Secretário fechando o semestre',
    'CALL sp_fechar_semestre(''2026.2'', 3)',
    'Apenas o Coordenador');
```

| Linha | O que faz |
|-------|-----------|
| 237 a 239 | O comando está entre aspas simples, e por isso as aspas dentro dele aparecem **dobradas**: `''2026.2''` vira `'2026.2'` quando o texto é lido. Espera-se `'Apenas o Coordenador'`. |

## Teste 12 (extra): duas travas de integridade (linhas 241 a 273)

Este teste cobre as duas regras novas das procedures: não repetir disciplina já aprovada, e não apagar nota já lançada. Ele roda **ainda dentro da mesma transação** dos testes 1 a 10, logo antes do ROLLBACK.

### Montar o cenário: uma turma aberta de Lógica (linhas 241 a 252)

- **Por que criar uma turma:** a única turma de Lógica da massa de dados (turma 1) está `Encerrada`, e a `sp_matricular_aluno` recusa turma encerrada **antes** de olhar se o aluno já foi aprovado. Sem uma turma aberta da mesma disciplina, o teste nunca chegaria na regra nova: a mensagem seria "Turma encerrada" e o teste não provaria nada. Por isso o teste cria uma turma aberta de Lógica (disciplina 1, professor 1, semestre 2026.2, 5 vagas).
- **Por que isso não suja a massa:** o INSERT acontece dentro da transação aberta na linha 97, e o `ROLLBACK` da linha 276 desfaz a turma junto com todo o resto.

```sql
-- ============================================================
-- TESTE 12 (extra): duas travas de integridade
--   a) quem já foi Aprovado numa disciplina não se matricula de novo
--      nela, mas quem reprovou pode repetir;
--   b) uma nota já lançada não pode ser apagada (NULL), mas dá para
--      lançar só a N1 numa matrícula que ainda não tem notas.
-- A turma de Lógica da massa está encerrada, então o teste cria uma
-- turma aberta da mesma disciplina (desfeita pelo ROLLBACK).
-- ============================================================
INSERT INTO turma (id_disciplina, id_professor, semestre, vagas, total_aulas, status)
VALUES (1, 1, '2026.2', 5, 80, 'Aberta');
SET @turma_repete = LAST_INSERT_ID();
```

| Linha | O que faz |
|-------|-----------|
| 241 a 249 | Comentário que descreve as duas travas e explica por que a turma é criada. |
| 250 e 251 | Cria a turma de Lógica aberta em 2026.2, com 5 vagas e 80 aulas. |
| 252 | Guarda o id dela em `@turma_repete` para os comandos seguintes. |

### Teste 12a: repetir disciplina em que já foi aprovado (linhas 254 a 258)

- **Cenário:** o aluno 1 foi Aprovado em Lógica (matrícula 1, turma 1) e tenta se matricular na nova turma aberta de Lógica.
- **Esperado:** erro contendo "já foi aprovado".
- **O que acontece:** "Aluno já foi aprovado nesta disciplina."
- **Por que importa:** prova a regra nova. O aluno está Ativo, a turma está aberta, ele não está matriculado nela e Lógica não tem pré-requisito, então só a regra do "já aprovado" pode barrá-lo.

```sql
-- aluno 1: Aprovado em Lógica (matrícula 1) | aluno 6: Reprovado por Nota
SET @comando_repete_aprovado = CONCAT('CALL sp_matricular_aluno(1, ', @turma_repete, ', 3)');
CALL sp_teste_erro('T12a: repetir disciplina em que já foi Aprovado',
    @comando_repete_aprovado,
    'já foi aprovado');
```

| Linha | O que faz |
|-------|-----------|
| 254 | Comentário: aluno 1 é Aprovado em Lógica; aluno 6 é Reprovado por Nota. |
| 255 | Monta o texto do comando com `CONCAT`, colocando dentro dele o id real da turma criada (`CALL sp_matricular_aluno(1, <id>, 3)`). O id só é conhecido durante o teste. |
| 256 a 258 | `sp_teste_erro` executa esse comando, que deve falhar, e espera a mensagem com `'já foi aprovado'`. |

### Teste 12b: quem reprovou pode repetir (linhas 260 a 263)

- **Cenário:** o aluno 6 foi Reprovado por Nota em Lógica (matrícula 6, notas 3,0 e 2,5) e se matricula na mesma turma nova.
- **Esperado:** a matrícula é criada (1 linha do aluno 6 nessa turma).
- **O que acontece:** a matrícula é criada, sem erro.
- **Por que importa:** o teste precisa mostrar que a regra **não barra demais**. Reprovar não impede de refazer a disciplina.

```sql
CALL sp_matricular_aluno(6, @turma_repete, 3);
SELECT COUNT(*) INTO @n_repete_reprovado
  FROM matricula WHERE id_aluno = 6 AND id_turma = @turma_repete;
CALL sp_teste_igual('T12b: quem reprovou pode repetir a disciplina', '1', @n_repete_reprovado);
```

| Linha | O que faz |
|-------|-----------|
| 260 | Chama a matrícula de verdade, sem `sp_teste_erro`, porque aqui **não** deve falhar. |
| 261 e 262 | Conta quantas matrículas o aluno 6 tem na turma nova. |
| 263 | Confere que o número é `'1'`. |

### Teste 12c: apagar uma nota já lançada (linhas 265 a 268)

- **Cenário:** a matrícula 17 (aluno 1, turma 3) já tem N1 = 8,0. O Coordenador tenta lançar com N1 em branco (NULL) e N2 = 9,0.
- **Esperado:** erro contendo "apagar uma nota".
- **O que acontece:** "Não é possível apagar uma nota já lançada: informe o novo valor."
- **Por que importa:** prova que o NULL no lugar de uma nota existente é recusado. Nada é gravado (a N2 = 9,0 também não entra, porque o erro cancela a procedure toda).

```sql
-- matrícula 17 (aluno 1, turma 3) já tem N1 = 8,0
CALL sp_teste_erro('T12c: apagar uma nota já lançada (N1 = NULL)',
    'CALL sp_lancar_notas(17, NULL, 9.0, 2, 1)',
    'apagar uma nota');
```

| Linha | O que faz |
|-------|-----------|
| 265 | Comentário: a matrícula 17 já tem N1 = 8,0. |
| 266 a 268 | `sp_lancar_notas(17, NULL, 9.0, 2, 1)`: N1 = NULL, N2 = 9,0, 2 faltas, usuário Coordenador. Espera-se `'apagar uma nota'` na mensagem. |

### Teste 12d: lançar só a N1 onde não há notas (linhas 270 a 273)

- **Cenário:** a matrícula 22 (aluno 2, turma 4) ainda não tem nenhuma nota. O Coordenador lança só a N1 = 7,0 e deixa a N2 em branco.
- **Esperado:** funciona, e a N1 fica gravada como 7,00.
- **O que acontece:** a N1 fica 7,00 (e a situação continua "Cursando", porque falta a N2).
- **Por que importa:** de novo, a regra não pode barrar demais. Lançar a primeira nota antes da segunda é o uso normal ao longo do semestre.

```sql
-- matrícula 22 (aluno 2, turma 4) ainda não tem nenhuma nota
CALL sp_lancar_notas(22, 7.0, NULL, 0, 1);
SELECT n1 INTO @n1_so_a_primeira FROM matricula WHERE id_matricula = 22;
CALL sp_teste_igual('T12d: lançar só a N1 onde ainda não há notas', '7.00', @n1_so_a_primeira);
```

| Linha | O que faz |
|-------|-----------|
| 270 | Comentário: a matrícula 22 não tem nenhuma nota. |
| 271 | Lança N1 = 7,0 e N2 = NULL, com 0 faltas. Como não há nota atual na N2, o NULL não apaga nada e a procedure aceita. |
| 272 | Lê a N1 gravada, guardando em `@n1_so_a_primeira`. |
| 273 | Confere que é `'7.00'`. |

### Desfazer tudo e conferir (linhas 275 a 281)

Agora o `ROLLBACK` desfaz **tudo** que os testes 1 a 10 e 12 fizeram.

```sql
-- Desfaz tudo o que os testes 1 a 12 alteraram.
ROLLBACK;

SELECT COUNT(*) INTO @log_depois FROM log_nota WHERE id_matricula = 20;
SELECT situacao INTO @situacao_depois FROM matricula WHERE id_matricula = 18;
CALL sp_teste_igual('ROLLBACK: log_nota da matrícula 20 voltou a vazio', '0', @log_depois);
CALL sp_teste_igual('ROLLBACK: matrícula 18 voltou a Em Exame', 'Em Exame', @situacao_depois);
```

| Linha | O que faz |
|-------|-----------|
| 275 | Comentário: desfaz tudo o que os testes 1 a 12 alteraram. |
| 276 | `ROLLBACK` desfaz tudo que os testes 1 a 10 e 12 alteraram: os exames das matrículas 18 e 24, as notas das matrículas 17, 20 e 22, a turma criada no teste 12 com a matrícula do aluno 6 nela, e os logs. A massa de dados volta ao que era. A tabela de resultados não é afetada, porque é MEMORY. |
| 278 e 279 | Lê quantos logs a matrícula 20 tem agora e a situação da matrícula 18. |
| 280 | Confere que o log da matrícula 20 voltou a `'0'`. |
| 281 | Confere que a matrícula 18 voltou a `'Em Exame'` (antes do teste ela estava assim; o exame a tinha mudado para Aprovado). Isso prova que o ROLLBACK funcionou. |

## Teste 11 (extra): fechamento de semestre (linhas 289 a 335)

Este teste fica **fora** da transação acima, porque a `sp_fechar_semestre` abre a própria transação (e o `START TRANSACTION` dela faria commit do que estivesse pendente). Para não encerrar o 2026.2 da massa de dados, o teste usa um semestre fictício, o `2099.1`, com turma e matrículas criadas aqui e apagadas no fim.

### Montar o cenário (linhas 289 a 298)

```sql
INSERT INTO turma (id_disciplina, id_professor, semestre, vagas, total_aulas, status)
VALUES (3, 4, '2099.1', 10, 60, 'Aberta');
SET @turma_fecha = LAST_INSERT_ID();
```

| Linha | O que faz |
|-------|-----------|
| 289 e 290 | Cria uma turma nova de Banco de Dados (disciplina 3, professor 4) no semestre `2099.1`, com 10 vagas, 60 aulas, status `'Aberta'`. |
| 291 | `LAST_INSERT_ID()` pega o id da turma criada e guarda em `@turma_fecha`, para os comandos seguintes usarem. |

```sql
-- aluno 1: 8,0 e 7,0 (Aprovado) | aluno 2: 5,0 e 6,0 sem exame (Em Exame)
-- aluno 3: 9,0 e sem N2 (Cursando)
INSERT INTO matricula (id_aluno, id_turma, n1, n2, exame, faltas, id_usuario) VALUES
(1, @turma_fecha, 8.0, 7.0, NULL, 0, 3),
(2, @turma_fecha, 5.0, 6.0, NULL, 0, 3),
(3, @turma_fecha, 9.0, NULL, NULL, 0, 3);
```

| Linha | O que faz |
|-------|-----------|
| 293 a 294 | Comentários com o cenário: aluno 1 com 8,0 e 7,0 (Aprovado); aluno 2 com 5,0 e 6,0 sem exame (Em Exame); aluno 3 com 9,0 e sem N2 (Cursando). |
| 295 a 298 | Insere as três matrículas diretamente na tabela, com as notas e o usuário 3. O `trg_situacao_inicial` calcula média e situação de cada uma ao inserir. |

### Teste 11a, 11b e 11c: o fechamento recusado e o ROLLBACK (linhas 300 a 307)

- **Cenário:** tentar fechar o `2099.1` com o aluno 3 sem a N2.
- **Esperado:** erro "sem N1 ou N2"; a turma continua `Aberta`; e a matrícula do aluno 2 continua `Em Exame` (mesmo que o cursor já tivesse passado por ela).
- **O que acontece:** "Matrícula (id) (Camila Rezende) sem N1 ou N2: lance as notas antes de fechar o semestre."
- **Por que importa:** é a prova do "tudo ou nada". O cursor percorre em ordem de id: passa primeiro pelo aluno 2 (Em Exame) e o transforma em Reprovado por Nota, e só depois chega ao aluno 3, que causa o erro. O ROLLBACK desfaz o que foi feito no aluno 2, e o teste confere isso.

```sql
CALL sp_teste_erro('T11a: fechar com matrícula sem N2 (Cursando)',
    'CALL sp_fechar_semestre(''2099.1'', 1)',
    'sem N1 ou N2');
```

| Linha | O que faz |
|-------|-----------|
| 300 a 302 | 11a: tenta `sp_fechar_semestre('2099.1', 1)`; espera-se `'sem N1 ou N2'` na mensagem. |

```sql
SELECT status INTO @status_turma FROM turma WHERE id_turma = @turma_fecha;
SELECT situacao INTO @situacao_em_exame FROM matricula
 WHERE id_turma = @turma_fecha AND id_aluno = 2;
CALL sp_teste_igual('T11b: ROLLBACK, a turma continua', 'Aberta', @status_turma);
CALL sp_teste_igual('T11c: ROLLBACK, o Em Exame não foi alterado', 'Em Exame', @situacao_em_exame);
```

| Linha | O que faz |
|-------|-----------|
| 303 | Lê o status da turma depois do erro. |
| 304 e 305 | Lê a situação do aluno 2 nessa turma. |
| 306 | 11b: a turma ainda deve estar `'Aberta'` (o encerramento não aconteceu). |
| 307 | 11c: o aluno 2 ainda deve estar `'Em Exame'` (o ROLLBACK desfez a mudança). |

### Corrigir e fechar com sucesso (linhas 309 a 320)

- **Cenário:** o Coordenador lança N2 = 8,0 para o aluno 3 (nota 9,0 e 8,0 dá 8,50, Aprovado) e tenta fechar de novo.
- **Esperado:** a turma vira `Encerrada`, o aluno 2 (Em Exame sem exame) vira `Reprovado por Nota`, e o resumo mostra **Aprovado 2 e Reprovado por Nota 1**.
- **O que acontece:** exatamente isso.

```sql
SELECT id_matricula INTO @matricula_sem_n2
  FROM matricula WHERE id_turma = @turma_fecha AND id_aluno = 3;
CALL sp_lancar_notas(@matricula_sem_n2, 9.0, 8.0, 0, 1);
```

| Linha | O que faz |
|-------|-----------|
| 309 a 310 | Descobre o id da matrícula do aluno 3 e guarda em `@matricula_sem_n2`. |
| 311 | Lança as notas 9,0 e 8,0 com 0 faltas, para o aluno 3 deixar de ser "Cursando". |

```sql
SELECT 'T11: sp_fechar_semestre(2099.1) (esperado: Aprovado 2, Reprovado por Nota 1)' AS teste;
CALL sp_fechar_semestre('2099.1', 1);
```

| Linha | O que faz |
|-------|-----------|
| 313 | Um `SELECT` de rótulo, dizendo o que se espera ver. |
| 314 | Chama o fechamento, que agora dá certo e devolve a tabela de contagem por situação. |

```sql
SELECT status INTO @status_turma FROM turma WHERE id_turma = @turma_fecha;
SELECT situacao INTO @situacao_em_exame FROM matricula
 WHERE id_turma = @turma_fecha AND id_aluno = 2;
CALL sp_teste_igual('T11d: turma encerrada', 'Encerrada', @status_turma);
CALL sp_teste_igual('T11e: Em Exame sem exame virou', 'Reprovado por Nota', @situacao_em_exame);
```

| Linha | O que faz |
|-------|-----------|
| 316 a 318 | Lê o status da turma e a situação do aluno 2, agora depois do fechamento. |
| 319 | 11d: a turma deve estar `'Encerrada'`. |
| 320 | 11e: o aluno 2 deve ter virado `'Reprovado por Nota'`. |

### Depois do fechamento (linhas 321 a 329)

- **11f:** lançar nota numa turma que já foi encerrada. **Esperado:** "Turma encerrada". **Acontece:** "Turma encerrada: as notas não podem mais ser alteradas."
- **11g:** fechar o mesmo semestre de novo. **Esperado:** "Não há turma aberta". **Acontece:** "Não há turma aberta neste semestre."
- **Por que importam:** provam que, depois do fechamento, a situação é definitiva e que não dá para fechar duas vezes.

```sql
SELECT CONCAT('CALL sp_lancar_notas(', id_matricula, ', 10.0, 10.0, 0, 1)')
  INTO @comando_nota_encerrada
  FROM matricula WHERE id_turma = @turma_fecha AND id_aluno = 1;
CALL sp_teste_erro('T11f: lançar nota em turma encerrada',
    @comando_nota_encerrada,
    'Turma encerrada');
```

| Linha | O que faz |
|-------|-----------|
| 321 a 323 | Monta, com `CONCAT`, o texto do comando `CALL sp_lancar_notas(<id>, 10.0, 10.0, 0, 1)` para a matrícula do aluno 1, e guarda em `@comando_nota_encerrada`. O id real só é conhecido durante o teste, e o `sp_teste_erro` pede o comando como texto. |
| 324 a 326 | 11f: executa esse comando, que deve falhar; espera-se `'Turma encerrada'`. |

```sql
CALL sp_teste_erro('T11g: fechar de novo o mesmo semestre',
    'CALL sp_fechar_semestre(''2099.1'', 1)',
    'Não há turma aberta');
```

| Linha | O que faz |
|-------|-----------|
| 327 a 329 | 11g: tenta fechar o `2099.1` outra vez; espera-se `'Não há turma aberta'`. |

### Limpeza do teste 11 (linhas 331 a 335)

```sql
DELETE FROM log_nota
 WHERE id_matricula IN (SELECT id_matricula FROM matricula WHERE id_turma = @turma_fecha);
DELETE FROM matricula WHERE id_turma = @turma_fecha;
DELETE FROM turma WHERE id_turma = @turma_fecha;
```

| Linha | O que faz |
|-------|-----------|
| 332 e 333 | Apaga os logs das matrículas da turma de ensaio. |
| 334 | Apaga as matrículas da turma de ensaio. |
| 335 | Apaga a turma de ensaio. A **ordem** importa: as chaves estrangeiras não deixam apagar uma turma que ainda tem matrícula, nem uma matrícula que ainda tem log. Por isso apaga-se de trás para frente: log, matrícula e depois turma. |

## Resultado final (linhas 337 a 346)

### A tabela esperado contra obtido (linhas 340 a 342)

```sql
SELECT teste, esperado, obtido, resultado FROM teste_resultado ORDER BY ordem;
SELECT SUM(resultado = 'OK') AS ok, SUM(resultado = 'FALHOU') AS falhou, COUNT(*) AS total
  FROM teste_resultado;
```

| Linha | O que faz |
|-------|-----------|
| 340 | Mostra a tabela com todas as verificações, na ordem em que foram registradas: teste, esperado, obtido, resultado. É a evidência para o relatório. |
| 341 e 342 | Soma quantas deram `OK`, quantas deram `FALHOU` e o total. O resultado esperado é **39 OK, 0 FALHOU, 39 no total**. |

### Limpeza final (linhas 344 a 346)

```sql
DROP TEMPORARY TABLE teste_resultado;
DROP PROCEDURE sp_teste_erro;
DROP PROCEDURE sp_teste_igual;
```

| Linha | O que faz |
|-------|-----------|
| 344 | Apaga a tabela temporária de resultados. |
| 345 e 346 | Apaga as duas procedures auxiliares dos testes. O banco fica só com o que é do sistema. |

# 4. Como as peças se encaixam

Pense nas suas procedures como o **balcão** do banco. A interface só fala com o balcão. O balcão confere as regras de quem pode e o que pode, e entrega o trabalho pesado para os triggers do Diego.

```
 TELAS (Leo / Guilherme, Java)
    |  só fazem CALL sp_... e SELECT em views
    v
 MYKAEL: procedures (02b)
    |
    |-- sp_LoginUsuario ---------> tabela usuario (hash do Guilherme)
    |
    |-- sp_matricular_aluno -----> INSERT matricula
    |                                   |  dispara (DIEGO)
    |                                   |--> trg_valida_vagas   (RN05, trava a turma)
    |                                   '--> trg_situacao_inicial (calcula media/situacao)
    |
    |-- sp_lancar_notas  --+
    |-- sp_lancar_exame  --+--> UPDATE matricula (n1,n2,exame,faltas,id_usuario)
    |                                   |  dispara (DIEGO)
    |                                   |--> trg_atualiza_situacao (BEFORE: recalcula)
    |                                   '--> trg_auditoria_nota    (AFTER: grava log_nota)
    |
    |-- sp_historico_aluno -----> vw_boletim (DIEGO)
    |
    '-- sp_fechar_semestre -----> cursor + transacao
                                   UPDATE so da situacao (trigger nao recalcula)
                                   UPDATE turma -> 'Encerrada'

 GUILHERME: tabelas e CHECKs (01_ddl), massa de dados (03_dados)
 MYKAEL: 04_testes.sql chama tudo isso e confere esperado x obtido
```

Em palavras:

- **Guilherme** criou as tabelas, os CHECKs (a regra de 0 a 10 e as grafias exatas) e a massa de dados. Os seus testes usam os IDs dos cenários que ele deixou descritos no topo do `03_dados.sql` (turma 3 lotada, aluno 16 sem pré-requisito, aluno 19 Trancado, e assim por diante).
- **Diego** escreveu os triggers e as views. Você **não calcula** média nem situação: grava as notas e o `trg_atualiza_situacao` calcula. A vaga é barrada pelo `trg_valida_vagas`. O log vem do `trg_auditoria_nota`, que lê o `id_usuario` que a sua procedure gravou. O `sp_historico_aluno` usa a `vw_boletim`.
- **Leo e Guilherme** (telas): o login chama a `sp_LoginUsuario` com o hash que o Java calcula; a tela de notas chama a `sp_lancar_notas` e a `sp_lancar_exame`; a matrícula chama a `sp_matricular_aluno`. A tela mostra a mensagem de erro do banco tal como vem da procedure, por isso as mensagens são em português legível.
- **Os dois controles de perfil:** a tela esconde as opções do Secretário, **e** as suas procedures recusam o Secretário mesmo se alguém chamar direto. Essa é a "defesa em duas camadas" do relatório.

# 5. Perguntas que o professor pode fazer (com respostas)

**1. O que é uma stored procedure e por que o sistema só acessa o banco por procedures e views?**

É um programa guardado dentro do banco, com nome, que se chama com `CALL`. A interface Java não tem nenhum INSERT, UPDATE ou DELETE: só `CALL sp_...` e `SELECT` em views. Isso concentra as regras de negócio no banco, evita SQL montado por concatenação de texto (que é a porta de entrada do SQL Injection, pois os valores vão sempre como parâmetros) e permite conferir o perfil do usuário em um lugar só.

**2. Por que SHA-256 para a senha? Tem algum problema?**

O enunciado aceitava SHA-256 ou BCRYPT. A grande vantagem é que a senha em texto nunca é guardada: o banco só tem o hash de 64 caracteres, e a senha digitada nem chega ao banco, porque o Java calcula o hash antes de chamar a procedure. Mas há limitações, e é melhor admiti-las: nosso hash é **SHA-256 puro, sem salt**. Duas pessoas com a mesma senha têm exatamente o mesmo hash (na massa de dados os 5 usuários usam `Senha@123` e têm o mesmo hash). E o SHA-256 é muito rápido, o que facilita ataque de força bruta ou de tabelas prontas. Num sistema de verdade, o recomendado seria bcrypt (ou Argon2), que já inclui salt e é lento de propósito.

**3. Por que a `sp_LoginUsuario` devolve vazio em vez de dizer "senha incorreta" ou "usuário não existe"?**

Porque dizer qual dos dois errou ajuda quem está tentando invadir: ele descobriria quais logins existem. Devolvendo sempre vazio (e a tela mostrando "Login ou senha inválidos"), a resposta é a mesma nos dois casos. A procedure também nunca devolve a coluna `senha_hash`, só id, nome, e-mail e perfil.

**4. Para que serve o `COLLATE utf8mb4_bin` no login?**

A collation padrão do banco ignora maiúscula e minúscula. Sem o `_bin`, o login `COORD.ANA` seria aceito como `coord.ana`, e um hash escrito em maiúsculas também passaria. Com `utf8mb4_bin`, a comparação é byte a byte: login e hash têm que ser exatamente iguais aos guardados. O mesmo cuidado é usado nas comparações de status ('Ativo', 'Aberta', 'Coordenador'), para combinarem com os CHECKs do DDL.

**5. O que é uma transação? Onde vocês usam?**

É um conjunto de operações tratadas como uma só: ou todas acontecem (COMMIT) ou nenhuma (ROLLBACK). Usamos na `sp_fechar_semestre`: ela altera várias matrículas e depois encerra as turmas. Se der erro no meio (por exemplo, achar um aluno sem notas), o ROLLBACK desfaz tudo, e o semestre nunca fica "meio fechado". O teste 11 prova isso: o aluno 2 já tinha sido mudado quando o erro apareceu, e depois do ROLLBACK ele volta a "Em Exame".

**6. O que é um cursor e por que vocês usaram um? Não bastaria um UPDATE só?**

Cursor percorre o resultado de um SELECT linha por linha. Usamos porque o enunciado pede cursor e transação no fechamento, e porque ele deixa conferir cada matrícula e apontar na mensagem **qual** matrícula e **qual** aluno está sem nota. Sendo honesto: só para transformar "Em Exame" em "Reprovado por Nota", um único UPDATE faria o mesmo de forma mais simples e rápida. O cursor se justifica pela checagem item a item e pela mensagem detalhada.

**7. O que fazem o `EXIT HANDLER FOR SQLEXCEPTION`, o `ROLLBACK` e o `RESIGNAL`?**

O handler é o plano B: se qualquer erro acontecer dentro do bloco (inclusive os SIGNAL que a própria procedure lança), ele roda `ROLLBACK`, que desfaz a transação, e `RESIGNAL`, que relança o mesmo erro para quem chamou. Sem o `RESIGNAL`, o erro seria engolido: o ROLLBACK aconteceria, mas a procedure terminaria sem avisar nada, e a interface acharia que o semestre foi fechado.

**8. Por que a conferência de perfil vem antes do `START TRANSACTION`?**

Para que um Secretário barrado não mexa em nada e nem abra transação. Além disso, `START TRANSACTION` faz commit implícito de qualquer transação aberta na conexão; conferindo antes, a recusa por perfil não tem efeito colateral. O ROLLBACK do handler só cobre o bloco interno, que é onde de fato há trabalho para desfazer.

**9. O que é `SIGNAL SQLSTATE '45000'`? Por que usar sempre ele?**

É o comando para lançar um erro definido pelo programador, com uma mensagem (`MESSAGE_TEXT`). O `45000` é o código padrão para isso. Combinamos no grupo usar sempre ele para regra de negócio quebrada, porque a interface só mostra a mensagem do erro. Por isso as mensagens são frases em português, como "Turma lotada: a turma 3 já tem 4 de 4 vagas ocupadas."

**10. Por que a `sp_lancar_notas` não calcula a média e a situação?**

Porque a regra tem que existir em um lugar só. Se a procedure calculasse, haveria duas cópias da regra (a da procedure e a do trigger do Diego) e, mais cedo ou mais tarde, elas divergiriam. A procedure só grava `n1`, `n2`, `faltas` e o `id_usuario`; o `trg_atualiza_situacao` (BEFORE UPDATE) recalcula média e situação na mesma gravação, e o `trg_auditoria_nota` (AFTER UPDATE) registra a mudança no log. Gravar o `id_usuario` no mesmo UPDATE é o que permite ao log saber quem lançou.

**11. O perfil é verificado na tela ou no banco? Por quê?**

Nos dois, de propósito. A tela esconde as opções que o perfil não pode usar, mas isso é conforto, não segurança: alguém que chame a procedure direto pularia a tela. Por isso as procedures `sp_lancar_notas`, `sp_lancar_exame` e `sp_fechar_semestre` conferem se o usuário é `'Coordenador'` e recusam com "Apenas o Coordenador pode ...". Os testes 6c e 10 provam isso.

**12. Como funciona a validação de pré-requisito (RN06)? E se a disciplina tiver dois pré-requisitos?**

O SELECT procura, entre os pré-requisitos da disciplina da turma, algum para o qual **não exista** uma matrícula do aluno, em turma daquela disciplina, com situação `'Aprovado'`. Se achar, recusa e diz o nome. Só "Aprovado" vale: cursando, em exame ou reprovado não cumprem. Se faltarem dois, a mensagem cita só o primeiro por ordem alfabética (`ORDER BY nome LIMIT 1`); resolvido esse, na próxima tentativa aparece o outro.

**13. O que acontece se duas pessoas se matriculam na última vaga ao mesmo tempo?**

A procedure confere vários itens, mas a vaga é barrada pelo `trg_valida_vagas` do Diego, que faz `SELECT ... FOR UPDATE` na linha da turma. A trava coloca as duas matrículas em fila: a segunda só segue depois que a primeira terminou, e então já enxerga a turma cheia e recebe "Turma lotada". Sem a trava, as duas contariam uma vaga livre e a turma ficaria com um aluno a mais.

**14. Como o teste consegue testar comandos que devem dar erro sem parar o script?**

Com a `sp_teste_erro`. Ela recebe o comando como texto, executa com `PREPARE` e `EXECUTE`, e tem um `CONTINUE HANDLER FOR SQLEXCEPTION` que, em vez de interromper, lê a mensagem do erro com `GET DIAGNOSTICS` e continua. Depois compara a mensagem com o trecho esperado e grava `OK` ou `FALHOU` na tabela de resultados. Se o comando que deveria falhar **não** falhar, o resultado é `FALHOU`.

**15. Por que os testes não bagunçam a massa de dados?**

Os testes 1 a 10 e 12 rodam dentro de uma transação que termina em `ROLLBACK`, e depois o próprio script confere que o ROLLBACK desfez tudo. Até a turma que o teste 12 cria some no ROLLBACK. O teste 11 usa um semestre fictício (2099.1) com turma e matrículas criadas e apagadas no fim, porque a `sp_fechar_semestre` abre a própria transação e não pode ser desfeita por fora. A tabela de resultados é temporária e do tipo MEMORY para o ROLLBACK não apagar o que ela já registrou. Só os contadores de AUTO_INCREMENT avançam.

**16. Por que `CREATE PROCEDURE` e `START TRANSACTION` complicam os testes?**

Porque eles fazem **commit implícito**: confirmam tudo que estava pendente. Por isso o roteiro tem duas fases: as procedures auxiliares são criadas **antes** do `START TRANSACTION` do teste (senão a criação fecharia a transação), e o teste da `sp_fechar_semestre` fica **fora** da transação dos testes 1 a 10 e 12 (o `START TRANSACTION` dela faria commit do que estivesse pendente).

**17. (Armadilha) A `sp_lancar_notas` aceita NULL. Isso não permite apagar uma nota?**

Era um problema, e foi corrigido. O UPDATE da procedure grava `n1 = p_n1` e `n2 = p_n2`; se alguém passasse NULL para uma nota que já existia, ela sumia (e a situação do aluno mudava). Agora a procedure busca as notas atuais da matrícula (`v_n1_atual` e `v_n2_atual`, linhas 201 e 202 e 213 a 217) e tem o bloco das linhas 226 a 230: se o novo valor é NULL **e** já existe nota gravada naquele campo, lança o erro "Não é possível apagar uma nota já lançada: informe o novo valor." O que continua permitido é lançar só a N1 numa matrícula que ainda não tem nota (nada a apagar) e trocar uma nota por outro valor. O teste 12c prova a recusa (matrícula 17, que tem N1 = 8,0) e o 12d prova que lançar só a N1 onde não há notas continua funcionando. Mesmo assim, qualquer troca de valor continua indo para o `log_nota`.

**18. (Armadilha) O aluno que já foi aprovado em uma disciplina pode se matricular de novo nela?**

Antes podia, em outra turma; foi corrigido. A procedure só impedia matrícula repetida na **mesma turma**. Agora, depois dessa checagem, o bloco das linhas 139 a 149 pergunta se o aluno tem alguma matrícula com situação `'Aprovado'` em qualquer turma da mesma disciplina e, se tiver, lança "Aluno já foi aprovado nesta disciplina." Quem foi reprovado (por nota ou por falta) pode repetir normalmente. O teste 12a prova a recusa (aluno 1, aprovado em Lógica) e o 12b prova que o reprovado (aluno 6) consegue se matricular. Para o teste funcionar, ele cria uma turma aberta de Lógica dentro da transação, porque a turma de Lógica da massa está encerrada e seria recusada antes por isso; o ROLLBACK desfaz essa turma.

**19. (Armadilha) O hash que a interface envia não é, na prática, a senha? Alguém com o hash consegue entrar?**

Quem tem o hash e consegue chamar a procedure diretamente consegue "logar", sim, porque a procedure compara o hash. Mas quem consegue chamar a procedure direto já tem acesso ao banco, e a interface não permite isso: ela recebe a senha digitada e calcula o hash de novo, então colar um hash na tela não funciona. O ponto fraco real é outro: a falta de salt, já citada na pergunta 2. O ideal seria proteger o banco com um usuário que só tenha permissão de `EXECUTE` nas procedures e `SELECT` nas views.

**20. (Armadilha) E se duas pessoas tentarem fechar o mesmo semestre ao mesmo tempo?**

Pelo desenho do código, o `SELECT COUNT(*) ... FOR UPDATE` trava as turmas abertas do semestre. A segunda chamada ficaria esperando a primeira terminar; depois do COMMIT, já não haveria turma aberta e ela receberia "Não há turma aberta neste semestre.". Esse comportamento é o que o código faz por desenho, mas nós não testamos com duas conexões ao mesmo tempo. O teste 11g prova o caso sequencial (fechar de novo depois de fechado).

# 6. Passo a passo para mostrar funcionando

Antes de começar, rode o `SGA_completo.sql` no MySQL Workbench. Ele recria o banco do zero, **já executa o `04_testes.sql`** (a tabela de 39 verificações aparece no fim da execução) e deixa a massa de dados intacta. Depois execute `USE sga_fbi;`.

**Dicas para o Workbench:** selecione **uma linha ou um bloco** e use Ctrl+Enter para rodar só o que está selecionado. Quando um comando deve dar erro, rode **sozinho**, porque um erro interrompe um script inteiro. Se um erro acontecer dentro de um `START TRANSACTION`, rode `ROLLBACK;` antes de continuar. Os números de `id_matricula` novos podem ser diferentes dos que aparecem aqui; o resto deve ser igual.

Todos os resultados abaixo foram conferidos em um MySQL 8.0 temporário carregado com o `SGA_completo.sql`.

## Passo 1: login (a senha de todos os usuários é Senha@123)

```sql
USE sga_fbi;

CALL sp_LoginUsuario('coord.ana', SHA2('Senha@123', 256));
```

Esperado: **uma linha** com `1 | Ana Beatriz Moura | ana.moura@fbi.edu.br | Coordenador`. Repare que não há coluna de senha.

```sql
CALL sp_LoginUsuario('coord.ana', SHA2('errada', 256));      -- vazio
CALL sp_LoginUsuario('ninguem', SHA2('Senha@123', 256));     -- vazio
CALL sp_LoginUsuario('COORD.ANA', SHA2('Senha@123', 256));   -- vazio (maiuscula)
```

Esperado: as três voltam **vazias**, sem mensagem de erro. Rode uma de cada vez.

Para mostrar o hash guardado (e a limitação do salt):

```sql
SELECT login, LEFT(senha_hash, 16) AS comeco_do_hash, LENGTH(senha_hash) AS tamanho, perfil
  FROM usuario;
```

Esperado: 5 linhas, todas com `a2ca37fe6fdc490b` no começo, tamanho 64. Os cinco hashes são iguais porque a senha é igual (e não há salt).

## Passo 2: matricular (com sucesso e com cada erro)

Matrícula que dá certo, e depois desfeita. O aluno 10 está Ativo e ainda não está na turma 4 (Banco de Dados), que tem 1 vaga:

```sql
START TRANSACTION;
CALL sp_matricular_aluno(10, 4, 3);
SELECT id_matricula, id_aluno, id_turma, situacao, id_usuario
  FROM matricula WHERE id_aluno = 10 AND id_turma = 4;
ROLLBACK;
```

Esperado: o `CALL` devolve uma coluna `id_matricula` com um número novo (por exemplo 41). A consulta mostra a matrícula com situação **Cursando** e `id_usuario` 3. O `ROLLBACK` desfaz. **Importante:** o aluno 10 ocupa a última vaga da turma 4. Se você rodar o `CALL` **sem** o `START TRANSACTION`/`ROLLBACK`, a matrícula fica gravada e a turma 4 passa a ficar lotada (qualquer outro aluno que tentar entrar recebe "Turma lotada"). Se isso acontecer, apague com `DELETE FROM matricula WHERE id_aluno = 10 AND id_turma = 4;`.

Agora os erros, **cada um sozinho**. Mensagens exatas:

```sql
CALL sp_matricular_aluno(5, 3, 3);    -- Turma lotada: a turma 3 já tem 4 de 4 vagas ocupadas.
CALL sp_matricular_aluno(9, 3, 3);    -- Falta pré-requisito: o aluno não foi aprovado em Lógica de Programação.
CALL sp_matricular_aluno(16, 5, 3);   -- Falta pré-requisito: o aluno não foi aprovado em Algoritmos.
CALL sp_matricular_aluno(19, 4, 3);   -- Aluno Trancado não pode se matricular: só alunos Ativos.
CALL sp_matricular_aluno(20, 4, 3);   -- Aluno Formado não pode se matricular: só alunos Ativos.
CALL sp_matricular_aluno(9, 4, 3);    -- Aluno já matriculado nesta turma.
CALL sp_matricular_aluno(10, 1, 3);   -- Turma encerrada: não aceita novas matrículas.
CALL sp_matricular_aluno(999, 4, 3);  -- Aluno não encontrado.
CALL sp_matricular_aluno(10, 999, 3); -- Turma não encontrada.
CALL sp_matricular_aluno(10, 4, 99);  -- Usuário não encontrado.
```

No Workbench cada um aparece como **Error Code: 1644.** seguido da mensagem acima. Dica de ordem de apresentação: comece pelo `(5, 3, 3)`, que mostra a regra de vagas vinda do trigger do Diego.

**Disciplina já aprovada (regra nova).** A turma de Lógica da massa está encerrada, e "turma encerrada" é conferida antes. Por isso é preciso criar, dentro de uma transação, uma turma aberta da mesma disciplina (é o que o teste 12 faz). Rode um comando por vez:

```sql
START TRANSACTION;

INSERT INTO turma (id_disciplina, id_professor, semestre, vagas, total_aulas, status)
VALUES (1, 1, '2026.2', 5, 80, 'Aberta');
SET @t12 = LAST_INSERT_ID();

CALL sp_matricular_aluno(1, @t12, 3);   -- Aluno já foi aprovado nesta disciplina.
CALL sp_matricular_aluno(6, @t12, 3);   -- funciona: devolve o id_matricula (aluno 6 foi reprovado em Lógica)

ROLLBACK;
```

Esperado: o aluno 1 (aprovado em Lógica) recebe **Error Code: 1644. Aluno já foi aprovado nesta disciplina.** O aluno 6 (reprovado por nota em Lógica) é matriculado e o `CALL` devolve um `id_matricula`. O `ROLLBACK` desfaz a matrícula e a turma criada.

## Passo 3: lançar notas (Coordenador) e auditoria

Dentro de uma transação, para poder desfazer:

```sql
START TRANSACTION;

CALL sp_lancar_notas(20, 7.0, 8.0, 3, 1);

SELECT n1, n2, faltas, media_final, situacao, id_usuario
  FROM matricula WHERE id_matricula = 20;

SELECT campo, valor_antigo, valor_novo, usuario
  FROM log_nota WHERE id_matricula = 20;

ROLLBACK;
```

Esperado na primeira consulta: 7.00, 8.00, 3, **7.50**, **Aprovado**, 1. Na segunda, **3 linhas** no log: `n1 NULL para 7.00`, `n2 NULL para 8.00` e `faltas 0.00 para 3.00`, todas com usuário 1. A média e a situação foram calculadas pelo trigger, não pela procedure.

Erros (cada um sozinho):

```sql
CALL sp_lancar_notas(20, 7.0, 8.0, 3, 3);      -- Apenas o Coordenador pode lançar notas.
CALL sp_lancar_notas(20, 7.0, 8.0, 3, 99);     -- Usuário não encontrado.
CALL sp_lancar_notas(999, 7.0, 8.0, 3, 1);     -- Matrícula não encontrada.
CALL sp_lancar_notas(1, 7.0, 8.0, 3, 1);       -- Turma encerrada: as notas não podem mais ser alteradas.
CALL sp_lancar_notas(20, 7.0, 8.0, NULL, 1);   -- Informe as faltas (zero ou mais).
CALL sp_lancar_notas(20, 7.0, 8.0, -1, 1);     -- Informe as faltas (zero ou mais).
CALL sp_lancar_notas(17, NULL, 9.0, 2, 1);     -- Não é possível apagar uma nota já lançada: informe o novo valor.
CALL sp_lancar_notas(20, 11.0, 8.0, 0, 1);     -- Check constraint 'ck_matricula_n1' is violated.
```

O último é o erro **3819** (do CHECK do Guilherme), não 1644. A matrícula 17 já tem N1 = 8,0, por isso o NULL no lugar dela é recusado.

Para mostrar que lançar **só a N1** onde ainda não há nota continua permitido (a matrícula 22 não tem nenhuma nota), dentro de uma transação:

```sql
START TRANSACTION;
CALL sp_lancar_notas(22, 7.0, NULL, 0, 1);
SELECT n1, n2, media_final, situacao FROM matricula WHERE id_matricula = 22;
ROLLBACK;
```

Esperado: N1 7.00, N2 NULL, média NULL e situação **Cursando** (falta a N2). Nenhum erro.

## Passo 4: lançar exame

A matrícula 18 está "Em Exame" (N1 6,0 e N2 7,0). Dentro de uma transação:

```sql
START TRANSACTION;
CALL sp_lancar_exame(18, 5.0, 1);
SELECT n1, n2, exame, media_final, situacao FROM matricula WHERE id_matricula = 18;
ROLLBACK;
```

Esperado: exame 5.00, **media_final 5.75**, **Aprovado**, porque (6,5 + 5,0) / 2 = 5,75. Com `2.0` no lugar do `5.0`, seria 4,25 e "Reprovado por Nota".

Erros (cada um sozinho):

```sql
CALL sp_lancar_exame(17, 5.0, 1);    -- Exame só pode ser lançado para matrícula Em Exame; a situação atual é Cursando.
CALL sp_lancar_exame(18, 5.0, 3);    -- Apenas o Coordenador pode lançar exame.
CALL sp_lancar_exame(999, 5.0, 1);   -- Matrícula não encontrada.
CALL sp_lancar_exame(18, NULL, 1);   -- Informe a nota do exame.
```

## Passo 5: histórico do aluno

```sql
CALL sp_historico_aluno(1);
```

Esperado: 3 linhas da Alice Monteiro, ordenadas por semestre: Lógica de Programação (2026.1, média 8.50, 95.00, Aprovado), Banco de Dados (2026.2, 7.50, 98.33, Aprovado) e Programação Orientada a Objetos (2026.2, N2 NULL, Cursando). Dentro de 2026.2, a ordem é alfabética pela disciplina.

```sql
CALL sp_historico_aluno(999);   -- Aluno não encontrado.
```

## Passo 6: fechar o semestre

**Primeiro, o erro (não muda nada).** Cada um sozinho:

```sql
CALL sp_fechar_semestre('2026.2', 1);
```

Esperado: **Error Code: 1644. Matrícula 17 (Alice Monteiro) sem N1 ou N2: lance as notas antes de fechar o semestre.** Confira que nada mudou:

```sql
SELECT id_turma, status FROM turma;     -- as turmas 3, 4 e 5 continuam Aberta
```

Mais erros:

```sql
CALL sp_fechar_semestre('2026.2', 3);   -- Apenas o Coordenador pode fechar o semestre.
CALL sp_fechar_semestre('2026-2', 1);   -- Semestre inválido: use o formato AAAA.S, por exemplo 2026.2.
CALL sp_fechar_semestre('2030.1', 1);   -- Não há turma aberta neste semestre.
CALL sp_fechar_semestre('2026.1', 1);   -- Não há turma aberta neste semestre. (já está Encerrada)
CALL sp_fechar_semestre('2026.2', 99);  -- Usuário não encontrado.
```

**Agora o fechamento que dá certo**, sem encerrar o 2026.2 de verdade. Use uma turma de ensaio no semestre fictício 2099.1 (é o mesmo cenário do teste 11). Rode **um comando por vez**:

```sql
INSERT INTO turma (id_disciplina, id_professor, semestre, vagas, total_aulas, status)
VALUES (3, 4, '2099.1', 10, 60, 'Aberta');
SET @t = LAST_INSERT_ID();

INSERT INTO matricula (id_aluno, id_turma, n1, n2, faltas, id_usuario) VALUES
(1, @t, 8.0, 7.0, 0, 3),
(2, @t, 5.0, 6.0, 0, 3),
(3, @t, 9.0, NULL, 0, 3);

SELECT aluno, n1, n2, media_final, situacao FROM vw_boletim WHERE id_turma = @t;
```

Esperado: Alice 7.50 Aprovado; Bernardo 5.50 Em Exame; Camila (N2 NULL) Cursando.

```sql
CALL sp_fechar_semestre('2099.1', 1);
```

Esperado: **Error Code: 1644. Matrícula (número) (Camila Rezende) sem N1 ou N2...** (é o ROLLBACK em ação). Confira: `SELECT status FROM turma WHERE id_turma = @t;` continua **Aberta**, e a situação do Bernardo continua **Em Exame**.

Agora lance a nota que faltava e feche:

```sql
SELECT id_matricula INTO @m3 FROM matricula WHERE id_turma = @t AND id_aluno = 3;
CALL sp_lancar_notas(@m3, 9.0, 8.0, 0, 1);
CALL sp_fechar_semestre('2099.1', 1);
```

Esperado: uma tabela `Aprovado 2` e `Reprovado por Nota 1`. Depois:

```sql
SELECT status FROM turma WHERE id_turma = @t;                       -- Encerrada
SELECT aluno, media_final, situacao FROM vw_boletim WHERE id_turma = @t;
CALL sp_lancar_notas(@m3, 10, 10, 0, 1);   -- Turma encerrada: as notas não podem mais ser alteradas.
CALL sp_fechar_semestre('2099.1', 1);      -- Não há turma aberta neste semestre.
```

Esperado na consulta: Alice Aprovado, **Bernardo Reprovado por Nota** (era Em Exame e não fez exame) e Camila Aprovado (8.50).

**Limpe a turma de ensaio** (na ordem: log, matrícula, turma):

```sql
DELETE FROM log_nota WHERE id_matricula IN (SELECT id_matricula FROM matricula WHERE id_turma = @t);
DELETE FROM matricula WHERE id_turma = @t;
DELETE FROM turma WHERE id_turma = @t;
```

Se o Workbench reclamar do "safe update mode" nos DELETE, desligue em Edit, Preferences, SQL Editor, "Safe Updates", e reconecte.

## Passo 7: o roteiro de testes completo

Para mostrar a tabela de 39 verificações, abra o `database/04_testes.sql` e rode o arquivo **inteiro** (ele não suja a massa de dados). No final aparecem duas tabelas: a lista de verificações (teste, esperado, obtido, resultado) e o resumo **ok = 39, falhou = 0, total = 39**. Pontos para mostrar ao professor: T2 (turma lotada), T4 (Trancado e Formado), T5 (CHECK da nota), T7 (média 9,00 com 68,75% de presença, Reprovado por Falta) e T11a a T11c (o fechamento recusado e o ROLLBACK) e T12 (não repetir disciplina aprovada e não apagar nota).

# 7. Se você só tem 5 minutos antes de apresentar

1. "Eu fiz 6 stored procedures e o roteiro de testes; a interface só chama as minhas procedures, não escreve direto nas tabelas."
2. "Toda regra quebrada vira `SIGNAL SQLSTATE '45000'` com mensagem em português, e a interface só mostra essa mensagem."
3. "A senha é guardada como hash SHA-256 de 64 caracteres; o Java calcula o hash, a senha nunca chega ao banco. Admito que não tem salt."
4. "O login devolve vazio nos dois casos de erro e nunca devolve a senha; a comparação é `utf8mb4_bin`, por bytes."
5. "A matrícula confere usuário, aluno Ativo, turma Aberta, matrícula repetida, disciplina já aprovada e pré-requisitos Aprovados; as vagas quem barra é o trigger do Diego."
6. "As procedures não calculam média nem situação: gravam as notas e o `id_usuario`, e os triggers calculam e fazem a auditoria. A regra existe em um lugar só."
7. "Lançar notas, lançar exame e fechar semestre exigem Coordenador; o banco barra mesmo que alguém chame a procedure direto. E uma nota já lançada não pode ser apagada com NULL."
8. "O fechamento usa cursor e transação: Em Exame sem exame vira Reprovado por Nota, e se tiver aluno sem nota dá ROLLBACK e nada muda. É tudo ou nada."
9. "As conferências de perfil vêm antes do `START TRANSACTION`, então quem é barrado não mexe em nada."
10. "Os testes: 12 testes e 39 verificações, todas OK; os erros são capturados por uma procedure com handler, os testes 1 a 10 e 12 terminam em ROLLBACK, e o fechamento é testado num semestre fictício 2099.1."
