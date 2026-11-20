-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 02c_procedures_cadastro.sql: cadastro de aluno pela interface
-- Responsável: Guilherme
-- ============================================================
-- Ordem de execução (ver README):
--   01_ddl -> 02a_functions_views_triggers -> 02b_procedures
--   -> 02c_procedures_cadastro -> 03_dados -> 04_testes
--
-- Este arquivo só depende das tabelas do 01_ddl.sql, então pode rodar
-- logo depois dele. Pode rodar de novo quantas vezes quiser: cada
-- objeto tem o seu DROP ... IF EXISTS antes do CREATE.
--
-- O que tem aqui (a interface não manda INSERT, UPDATE nem DELETE):
--   sp_cadastrar_aluno  cria o aluno (status 'Ativo') e devolve id_aluno
--   sp_editar_aluno     altera todos os dados, inclusive o status
--   sp_excluir_aluno    exclui só quem nunca se matriculou
--   vw_alunos           listagem de alunos com o nome do curso
--
-- Combinados do grupo usados aqui:
--   * Regra quebrada vira SIGNAL SQLSTATE '45000' com MESSAGE_TEXT
--     legível: a interface só mostra essa mensagem.
--   * CPF: só os 11 dígitos, sem ponto nem traço.
--   * Prefixos sp_ vw_; parâmetros p_, variáveis v_.
--
-- Decisões:
--   1. As procedures conferem tudo antes do INSERT/UPDATE para dar
--      mensagem clara (CPF repetido, curso inexistente...). Os UNIQUE
--      e CHECKs do DDL continuam valendo: o handler do erro 1062 cobre
--      duas pessoas cadastrando o mesmo aluno ao mesmo tempo.
--   2. Excluir aluno com matrícula não é permitido (a FK quebraria e
--      o histórico se perderia): o caminho é editar para 'Trancado'.
--   3. Textos recebem TRIM; nome, RA e e-mail em branco são recusados.
-- ============================================================

USE sga_fbi;

DROP PROCEDURE IF EXISTS sp_excluir_aluno;
DROP PROCEDURE IF EXISTS sp_editar_aluno;
DROP PROCEDURE IF EXISTS sp_cadastrar_aluno;
DROP VIEW IF EXISTS vw_alunos;


-- ============================================================
-- VIEW
-- ============================================================

-- ------------------------------------------------------------
-- vw_alunos
-- Uma linha por aluno, com o nome do curso, para a tela de
-- listagem do Secretário.
--
-- Uso:  SELECT * FROM vw_alunos WHERE nome LIKE ? ORDER BY nome;
-- ------------------------------------------------------------
CREATE VIEW vw_alunos AS
SELECT a.id_aluno,
       a.ra,
       a.nome,
       a.cpf,
       a.email,
       a.data_nascimento,
       a.id_curso,
       c.nome  AS curso,
       c.turno AS turno,
       a.status
  FROM aluno a
  JOIN curso c ON c.id_curso = a.id_curso;


-- ============================================================
-- PROCEDURES
-- ============================================================
DELIMITER $$

-- ------------------------------------------------------------
-- sp_cadastrar_aluno
-- Cria o aluno com status 'Ativo' e devolve uma linha com o
-- id_aluno gerado.
--
-- Uso:  CALL sp_cadastrar_aluno('2026010', 'Maria Silva',
--           '12345678901', 'maria@email.com', '2005-03-14', 1);
-- Erros (45000): campo em branco, CPF fora do formato, e-mail sem @,
--   data de nascimento no futuro, curso inexistente, RA, CPF ou
--   e-mail já cadastrados.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_cadastrar_aluno(
    IN p_ra               VARCHAR(20),
    IN p_nome             VARCHAR(100),
    IN p_cpf              CHAR(11),
    IN p_email            VARCHAR(100),
    IN p_data_nascimento  DATE,
    IN p_id_curso         INT
)
BEGIN
    DECLARE EXIT HANDLER FOR 1062
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'RA, CPF ou e-mail já cadastrado para outro aluno.';

    SET p_ra    = TRIM(p_ra);
    SET p_nome  = TRIM(p_nome);
    SET p_email = TRIM(p_email);

    IF p_ra IS NULL OR p_ra = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe o RA do aluno.';
    END IF;
    IF p_nome IS NULL OR p_nome = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe o nome do aluno.';
    END IF;
    IF p_cpf IS NULL OR NOT REGEXP_LIKE(p_cpf, '^[0-9]{11}$') THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'CPF inválido: informe os 11 dígitos, sem ponto nem traço.';
    END IF;
    IF p_email IS NULL OR p_email NOT LIKE '_%@_%' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'E-mail inválido.';
    END IF;
    IF p_data_nascimento IS NULL OR p_data_nascimento > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data de nascimento inválida.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM curso WHERE id_curso = p_id_curso) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Curso não encontrado.';
    END IF;
    IF EXISTS (SELECT 1 FROM aluno WHERE ra = p_ra) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Já existe um aluno com este RA.';
    END IF;
    IF EXISTS (SELECT 1 FROM aluno WHERE cpf = p_cpf) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Já existe um aluno com este CPF.';
    END IF;
    IF EXISTS (SELECT 1 FROM aluno WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Já existe um aluno com este e-mail.';
    END IF;

    INSERT INTO aluno (ra, nome, cpf, email, data_nascimento, id_curso, status)
    VALUES (p_ra, p_nome, p_cpf, p_email, p_data_nascimento, p_id_curso, 'Ativo');

    SELECT LAST_INSERT_ID() AS id_aluno;
END$$

-- ------------------------------------------------------------
-- sp_editar_aluno
-- Altera todos os dados do aluno, inclusive o status ('Ativo',
-- 'Trancado' ou 'Formado'). A tela manda os campos que não mudaram
-- com o valor atual.
--
-- Uso:  CALL sp_editar_aluno(7, '2026010', 'Maria Silva',
--           '12345678901', 'maria@email.com', '2005-03-14', 1, 'Trancado');
-- Erros (45000): os mesmos do cadastro, mais aluno inexistente e
--   status fora de 'Ativo' | 'Trancado' | 'Formado'.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_editar_aluno(
    IN p_id_aluno         INT,
    IN p_ra               VARCHAR(20),
    IN p_nome             VARCHAR(100),
    IN p_cpf              CHAR(11),
    IN p_email            VARCHAR(100),
    IN p_data_nascimento  DATE,
    IN p_id_curso         INT,
    IN p_status           VARCHAR(8)
)
BEGIN
    DECLARE EXIT HANDLER FOR 1062
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'RA, CPF ou e-mail já cadastrado para outro aluno.';

    SET p_ra    = TRIM(p_ra);
    SET p_nome  = TRIM(p_nome);
    SET p_email = TRIM(p_email);

    IF NOT EXISTS (SELECT 1 FROM aluno WHERE id_aluno = p_id_aluno) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno não encontrado.';
    END IF;
    IF p_ra IS NULL OR p_ra = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe o RA do aluno.';
    END IF;
    IF p_nome IS NULL OR p_nome = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe o nome do aluno.';
    END IF;
    IF p_cpf IS NULL OR NOT REGEXP_LIKE(p_cpf, '^[0-9]{11}$') THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'CPF inválido: informe os 11 dígitos, sem ponto nem traço.';
    END IF;
    IF p_email IS NULL OR p_email NOT LIKE '_%@_%' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'E-mail inválido.';
    END IF;
    IF p_data_nascimento IS NULL OR p_data_nascimento > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data de nascimento inválida.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM curso WHERE id_curso = p_id_curso) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Curso não encontrado.';
    END IF;
    IF p_status IS NULL
       OR p_status COLLATE utf8mb4_bin NOT IN ('Ativo', 'Trancado', 'Formado') THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Status inválido: use Ativo, Trancado ou Formado.';
    END IF;
    IF EXISTS (SELECT 1 FROM aluno WHERE ra = p_ra AND id_aluno <> p_id_aluno) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Já existe outro aluno com este RA.';
    END IF;
    IF EXISTS (SELECT 1 FROM aluno WHERE cpf = p_cpf AND id_aluno <> p_id_aluno) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Já existe outro aluno com este CPF.';
    END IF;
    IF EXISTS (SELECT 1 FROM aluno WHERE email = p_email AND id_aluno <> p_id_aluno) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Já existe outro aluno com este e-mail.';
    END IF;

    UPDATE aluno
       SET ra              = p_ra,
           nome            = p_nome,
           cpf             = p_cpf,
           email           = p_email,
           data_nascimento = p_data_nascimento,
           id_curso        = p_id_curso,
           status          = p_status
     WHERE id_aluno = p_id_aluno;
END$$

-- ------------------------------------------------------------
-- sp_excluir_aluno
-- Exclui o aluno só se ele nunca teve matrícula. Quem já cursou
-- alguma coisa mantém o histórico: a saída é trancar.
--
-- Uso:  CALL sp_excluir_aluno(7);
-- Erros (45000): aluno inexistente; aluno com matrículas.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_excluir_aluno(IN p_id_aluno INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM aluno WHERE id_aluno = p_id_aluno) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno não encontrado.';
    END IF;
    IF EXISTS (SELECT 1 FROM matricula WHERE id_aluno = p_id_aluno) THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Aluno tem matrículas: tranque o aluno em vez de excluir.';
    END IF;

    DELETE FROM aluno WHERE id_aluno = p_id_aluno;
END$$

DELIMITER ;
