-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- SGA_completo.sql: todos os scripts do banco, na ordem de execucao
--
-- ARQUIVO GERADO por database/gerar_SGA_completo.ps1. NAO EDITE AQUI:
-- altere o script de origem e gere de novo.
--
-- ATENCAO: apaga e recria o banco sga_fbi do zero.
-- No Workbench: abra este arquivo e execute tudo.
-- Os testes do final que devem falhar param o script: desligue a
-- opcao de parar no erro ou rode o bloco de testes um por vez.
--
-- Conteudo, na ordem:
--   01_ddl.sql
--   02a_functions_views_triggers.sql
--   02b_procedures.sql
--   02c_procedures_cadastro.sql
--   03_dados.sql
--   04_testes.sql
-- ============================================================


-- ============================================================
-- >>> INICIO DE 01_ddl.sql
-- ============================================================

-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 01_ddl.sql: criação do banco, tabelas, índices e constraints
-- Responsável: Guilherme
-- ============================================================
-- Ordem de execução (ver README):
--   01_ddl -> 02a_functions_views_triggers -> 02b_procedures
--   -> 02c_procedures_cadastro -> 03_dados -> 04_testes
--
-- ATENÇÃO: este script APAGA e recria o banco sga_fbi do zero.
--
-- Combinados do grupo usados aqui:
--   * Textos exatos. O CHECK compara com COLLATE utf8mb4_bin, então
--     'Em exame' ou 'Secretário' são recusados:
--       usuario.perfil      'Secretario' | 'Coordenador'
--       curso.turno         'Matutino' | 'Vespertino' | 'Noturno'
--       aluno.status        'Ativo' | 'Trancado' | 'Formado'
--       turma.status        'Aberta' | 'Encerrada'
--       matricula.situacao  'Cursando' | 'Aprovado' | 'Em Exame'
--                           | 'Reprovado por Nota' | 'Reprovado por Falta'
--   * Senha: SHA-256 em hexadecimal minúsculo, CHAR(64)
--     (no INSERT: SHA2('senha', 256)).
--   * Notas: DECIMAL(4,2) entre 0 e 10 (RN07).
--   * CPF: só os 11 dígitos, sem ponto nem traço.
--   * Semestre: 'AAAA.S', por exemplo '2026.1' e '2026.2'.
-- ============================================================

DROP DATABASE IF EXISTS sga_fbi;
CREATE DATABASE sga_fbi
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
USE sga_fbi;

-- ------------------------------------------------------------
-- usuario: quem usa o sistema (Secretário ou Coordenador)
-- ------------------------------------------------------------
CREATE TABLE usuario (
    id_usuario  INT          NOT NULL AUTO_INCREMENT,
    nome        VARCHAR(100) NOT NULL,
    cpf         CHAR(11)     NOT NULL,
    email       VARCHAR(100) NOT NULL,
    login       VARCHAR(30)  NOT NULL,
    senha_hash  CHAR(64)     NOT NULL,
    perfil      VARCHAR(11)  NOT NULL,
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_cpf   UNIQUE (cpf),
    CONSTRAINT uq_usuario_email UNIQUE (email),
    CONSTRAINT uq_usuario_login UNIQUE (login),
    CONSTRAINT ck_usuario_cpf CHECK (REGEXP_LIKE(cpf, '^[0-9]{11}$')),
    CONSTRAINT ck_usuario_senha_hash CHECK (REGEXP_LIKE(senha_hash, '^[0-9a-f]{64}$', 'c')),
    CONSTRAINT ck_usuario_perfil CHECK (perfil COLLATE utf8mb4_bin IN ('Secretario', 'Coordenador'))
);

-- ------------------------------------------------------------
-- curso
-- valor_mensalidade: além do mínimo, para o faturamento por curso
-- ------------------------------------------------------------
CREATE TABLE curso (
    id_curso             INT           NOT NULL AUTO_INCREMENT,
    nome                 VARCHAR(100)  NOT NULL,
    carga_horaria_total  INT           NOT NULL,
    turno                VARCHAR(10)   NOT NULL,
    valor_mensalidade    DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_curso PRIMARY KEY (id_curso),
    CONSTRAINT uq_curso_nome_turno UNIQUE (nome, turno),
    CONSTRAINT ck_curso_carga_horaria CHECK (carga_horaria_total > 0),
    CONSTRAINT ck_curso_turno CHECK (turno COLLATE utf8mb4_bin IN ('Matutino', 'Vespertino', 'Noturno')),
    CONSTRAINT ck_curso_mensalidade CHECK (valor_mensalidade >= 0)
);

-- ------------------------------------------------------------
-- disciplina: periodo = semestre da grade em que ela é oferecida
-- ------------------------------------------------------------
CREATE TABLE disciplina (
    id_disciplina  INT          NOT NULL AUTO_INCREMENT,
    id_curso       INT          NOT NULL,
    nome           VARCHAR(100) NOT NULL,
    carga_horaria  INT          NOT NULL,
    periodo        TINYINT      NOT NULL,
    CONSTRAINT pk_disciplina PRIMARY KEY (id_disciplina),
    CONSTRAINT uq_disciplina_curso_nome UNIQUE (id_curso, nome),
    CONSTRAINT fk_disciplina_curso FOREIGN KEY (id_curso)
        REFERENCES curso (id_curso),
    CONSTRAINT ck_disciplina_carga_horaria CHECK (carga_horaria > 0),
    CONSTRAINT ck_disciplina_periodo CHECK (periodo BETWEEN 1 AND 12)
);

-- ------------------------------------------------------------
-- pre_requisito: autorrelacionamento N:N de disciplina
-- (id_disciplina exige aprovação em id_disciplina_requisito)
-- ------------------------------------------------------------
CREATE TABLE pre_requisito (
    id_disciplina            INT NOT NULL,
    id_disciplina_requisito  INT NOT NULL,
    CONSTRAINT pk_pre_requisito PRIMARY KEY (id_disciplina, id_disciplina_requisito),
    CONSTRAINT fk_pre_requisito_disciplina FOREIGN KEY (id_disciplina)
        REFERENCES disciplina (id_disciplina),
    CONSTRAINT fk_pre_requisito_requisito FOREIGN KEY (id_disciplina_requisito)
        REFERENCES disciplina (id_disciplina),
    CONSTRAINT ck_pre_requisito_diferente CHECK (id_disciplina <> id_disciplina_requisito)
);

-- ------------------------------------------------------------
-- professor
-- ------------------------------------------------------------
CREATE TABLE professor (
    id_professor   INT          NOT NULL AUTO_INCREMENT,
    nome           VARCHAR(100) NOT NULL,
    cpf            CHAR(11)     NOT NULL,
    email          VARCHAR(100) NOT NULL,
    titulacao      VARCHAR(12)  NOT NULL,
    data_admissao  DATE         NOT NULL,
    CONSTRAINT pk_professor PRIMARY KEY (id_professor),
    CONSTRAINT uq_professor_cpf   UNIQUE (cpf),
    CONSTRAINT uq_professor_email UNIQUE (email),
    CONSTRAINT ck_professor_cpf CHECK (REGEXP_LIKE(cpf, '^[0-9]{11}$')),
    CONSTRAINT ck_professor_titulacao CHECK (titulacao COLLATE utf8mb4_bin IN ('Graduado', 'Especialista', 'Mestre', 'Doutor'))
);

-- ------------------------------------------------------------
-- aluno
-- ------------------------------------------------------------
CREATE TABLE aluno (
    id_aluno         INT          NOT NULL AUTO_INCREMENT,
    ra               VARCHAR(20)  NOT NULL,
    nome             VARCHAR(100) NOT NULL,
    cpf              CHAR(11)     NOT NULL,
    email            VARCHAR(100) NOT NULL,
    data_nascimento  DATE         NOT NULL,
    id_curso         INT          NOT NULL,
    status           VARCHAR(8)   NOT NULL DEFAULT 'Ativo',
    CONSTRAINT pk_aluno PRIMARY KEY (id_aluno),
    CONSTRAINT uq_aluno_ra    UNIQUE (ra),
    CONSTRAINT uq_aluno_cpf   UNIQUE (cpf),
    CONSTRAINT uq_aluno_email UNIQUE (email),
    CONSTRAINT fk_aluno_curso FOREIGN KEY (id_curso)
        REFERENCES curso (id_curso),
    CONSTRAINT ck_aluno_cpf CHECK (REGEXP_LIKE(cpf, '^[0-9]{11}$')),
    CONSTRAINT ck_aluno_status CHECK (status COLLATE utf8mb4_bin IN ('Ativo', 'Trancado', 'Formado'))
);

-- ------------------------------------------------------------
-- turma
-- status: além do mínimo, a sp_fechar_semestre marca 'Encerrada'
-- ------------------------------------------------------------
CREATE TABLE turma (
    id_turma       INT        NOT NULL AUTO_INCREMENT,
    id_disciplina  INT        NOT NULL,
    id_professor   INT        NOT NULL,
    semestre       CHAR(6)    NOT NULL,
    vagas          INT        NOT NULL,
    total_aulas    INT        NOT NULL,
    status         VARCHAR(9) NOT NULL DEFAULT 'Aberta',
    CONSTRAINT pk_turma PRIMARY KEY (id_turma),
    CONSTRAINT fk_turma_disciplina FOREIGN KEY (id_disciplina)
        REFERENCES disciplina (id_disciplina),
    CONSTRAINT fk_turma_professor FOREIGN KEY (id_professor)
        REFERENCES professor (id_professor),
    CONSTRAINT ck_turma_semestre CHECK (REGEXP_LIKE(semestre, '^[0-9]{4}[.][12]$')),
    CONSTRAINT ck_turma_vagas CHECK (vagas > 0),
    CONSTRAINT ck_turma_total_aulas CHECK (total_aulas > 0),
    CONSTRAINT ck_turma_status CHECK (status COLLATE utf8mb4_bin IN ('Aberta', 'Encerrada'))
);

-- ------------------------------------------------------------
-- matricula: aluno x turma, com notas, faltas e situação
-- media_final e situacao são preenchidas pelo trg_atualiza_situacao.
-- id_usuario: quem fez a última operação (matrícula ou notas).
-- ------------------------------------------------------------
CREATE TABLE matricula (
    id_matricula    INT          NOT NULL AUTO_INCREMENT,
    id_aluno        INT          NOT NULL,
    id_turma        INT          NOT NULL,
    data_matricula  DATE         NOT NULL DEFAULT (CURRENT_DATE),
    n1              DECIMAL(4,2) NULL,
    n2              DECIMAL(4,2) NULL,
    exame           DECIMAL(4,2) NULL,
    faltas          INT          NOT NULL DEFAULT 0,
    media_final     DECIMAL(4,2) NULL,
    situacao        VARCHAR(19)  NOT NULL DEFAULT 'Cursando',
    id_usuario      INT          NOT NULL,
    CONSTRAINT pk_matricula PRIMARY KEY (id_matricula),
    CONSTRAINT uq_matricula_aluno_turma UNIQUE (id_aluno, id_turma),
    CONSTRAINT fk_matricula_aluno FOREIGN KEY (id_aluno)
        REFERENCES aluno (id_aluno),
    CONSTRAINT fk_matricula_turma FOREIGN KEY (id_turma)
        REFERENCES turma (id_turma),
    CONSTRAINT fk_matricula_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario (id_usuario),
    CONSTRAINT ck_matricula_n1 CHECK (n1 BETWEEN 0 AND 10),
    CONSTRAINT ck_matricula_n2 CHECK (n2 BETWEEN 0 AND 10),
    CONSTRAINT ck_matricula_exame CHECK (exame BETWEEN 0 AND 10),
    CONSTRAINT ck_matricula_media_final CHECK (media_final BETWEEN 0 AND 10),
    CONSTRAINT ck_matricula_faltas CHECK (faltas >= 0),
    CONSTRAINT ck_matricula_situacao CHECK (situacao COLLATE utf8mb4_bin IN (
        'Cursando', 'Aprovado', 'Em Exame', 'Reprovado por Nota', 'Reprovado por Falta'))
);

-- ------------------------------------------------------------
-- log_nota: auditoria das alterações de nota (RN08)
-- Alimentada pelo trg_auditoria_nota, uma linha por campo alterado.
-- usuario: id do usuário do SGA que alterou (vem de matricula.id_usuario).
-- valor_*: DECIMAL(6,2) para caber também faltas, se o trigger registrar.
-- ------------------------------------------------------------
CREATE TABLE log_nota (
    id_log        INT          NOT NULL AUTO_INCREMENT,
    id_matricula  INT          NOT NULL,
    campo         VARCHAR(20)  NOT NULL,
    valor_antigo  DECIMAL(6,2) NULL,
    valor_novo    DECIMAL(6,2) NULL,
    usuario       INT          NOT NULL,
    data_hora     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_log_nota PRIMARY KEY (id_log),
    CONSTRAINT fk_log_nota_matricula FOREIGN KEY (id_matricula)
        REFERENCES matricula (id_matricula),
    CONSTRAINT fk_log_nota_usuario FOREIGN KEY (usuario)
        REFERENCES usuario (id_usuario)
);

-- ------------------------------------------------------------
-- Índices
-- ra, cpf, email e login já têm índice pelos UNIQUE acima, e algumas
-- FKs já são cobertas por PK/UNIQUE compostos (disciplina.id_curso,
-- pre_requisito.id_disciplina, matricula.id_aluno).
-- Abaixo: as demais FKs e as colunas usadas em busca e ordenação.
-- ------------------------------------------------------------
CREATE INDEX idx_pre_requisito_requisito ON pre_requisito (id_disciplina_requisito);
CREATE INDEX idx_aluno_curso             ON aluno (id_curso);
CREATE INDEX idx_aluno_nome              ON aluno (nome);
CREATE INDEX idx_turma_disciplina        ON turma (id_disciplina);
CREATE INDEX idx_turma_professor         ON turma (id_professor);
CREATE INDEX idx_turma_semestre          ON turma (semestre);
CREATE INDEX idx_matricula_turma         ON matricula (id_turma);
CREATE INDEX idx_matricula_usuario       ON matricula (id_usuario);
CREATE INDEX idx_log_nota_matricula      ON log_nota (id_matricula);
CREATE INDEX idx_log_nota_usuario        ON log_nota (usuario);

DELIMITER ;
-- <<< FIM DE 01_ddl.sql


-- ============================================================
-- >>> INICIO DE 02a_functions_views_triggers.sql
-- ============================================================

-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 02a_functions_views_triggers.sql: functions, views e triggers
-- Responsável: Diego
-- ============================================================
-- Ordem de execução (ver README):
--   01_ddl -> 02a_functions_views_triggers -> 02b_procedures
--   -> 02c_procedures_cadastro -> 03_dados -> 04_testes
--
-- Dentro deste arquivo a ordem é functions -> views -> triggers,
-- porque as views e os triggers usam as functions.
--
-- Pode rodar de novo quantas vezes quiser: cada objeto tem o seu
-- DROP ... IF EXISTS antes do CREATE.
--
-- O que tem aqui:
--   Functions  fn_calcular_media      RN01, RN03
--              fn_frequencia_calc     auxiliar (recebe os valores)
--              fn_frequencia          fórmula de presença do enunciado
--              fn_situacao_calc       auxiliar (recebe os valores)
--              fn_situacao            RN02, RN03, RN04
--              fn_cr_aluno            opcional (ponto extra)
--   Views      vw_boletim             boletim + ids para a tela de notas
--              vw_turmas_lotacao      vagas, matriculados, % de ocupação
--              vw_desempenho_turma    média, maior/menor nota, % aprov./reprov.
--              vw_faturamento_curso   alunos ativos x mensalidade
--   Triggers   trg_valida_vagas       BEFORE INSERT  RN05
--              trg_situacao_inicial   BEFORE INSERT  (além do mínimo)
--              trg_atualiza_situacao  BEFORE UPDATE  RN01 a RN04
--              trg_auditoria_nota     AFTER UPDATE   RN08
--
-- Combinados do grupo usados aqui:
--   * Situações com a grafia exata: 'Cursando', 'Aprovado', 'Em Exame',
--     'Reprovado por Nota', 'Reprovado por Falta'.
--   * Regra quebrada vira SIGNAL SQLSTATE '45000' com MESSAGE_TEXT legível.
--   * Prefixos fn_ vw_ trg_; parâmetros p_, variáveis v_.
--
-- Decisões que valem para o sistema todo (detalhes em
-- relatorio/functions_views_triggers.md):
--   1. As médias são arredondadas para 2 casas ANTES de comparar com
--      7,0 / 4,0 / 5,0. Assim a situação sempre bate com a média que
--      aparece no boletim (6,995 vira 7,00 e é 'Aprovado').
--   2. A frequência é truncada (não arredondada) em 2 casas, para
--      74,999% nunca aparecer como 75,00%.
--   3. O exame só entra na média de quem está na faixa de exame
--      (média parcial de 4,00 a 6,99).
--   4. 'Reprovado por Falta' ganha de tudo (RN04), inclusive antes de
--      as notas serem lançadas.
-- ============================================================

USE sga_fbi;

-- Limpeza, na ordem inversa da dependência
DROP TRIGGER IF EXISTS trg_auditoria_nota;
DROP TRIGGER IF EXISTS trg_atualiza_situacao;
DROP TRIGGER IF EXISTS trg_situacao_inicial;
DROP TRIGGER IF EXISTS trg_valida_vagas;

DROP VIEW IF EXISTS vw_faturamento_curso;
DROP VIEW IF EXISTS vw_desempenho_turma;
DROP VIEW IF EXISTS vw_turmas_lotacao;
DROP VIEW IF EXISTS vw_boletim;

DROP FUNCTION IF EXISTS fn_cr_aluno;
DROP FUNCTION IF EXISTS fn_situacao;
DROP FUNCTION IF EXISTS fn_situacao_calc;
DROP FUNCTION IF EXISTS fn_frequencia;
DROP FUNCTION IF EXISTS fn_frequencia_calc;
DROP FUNCTION IF EXISTS fn_calcular_media;


-- ============================================================
-- FUNCTIONS
-- ============================================================
DELIMITER $$

-- ------------------------------------------------------------
-- fn_calcular_media(p_n1, p_n2, p_exame)  ->  DECIMAL(4,2)
-- RN01: média parcial = (N1 + N2) / 2
-- RN03: média final   = (média parcial + exame) / 2
--
--   falta N1 ou N2                  -> NULL (ainda não tem média)
--   parcial fora da faixa de exame  -> a própria parcial
--   parcial na faixa, sem exame     -> a parcial (por enquanto)
--   parcial na faixa, com exame     -> (parcial + exame) / 2
--
-- Exemplos: (8, 9, NULL) = 8.50 | (5, 6, NULL) = 5.50
--           (5, 6, 7) = 6.25    | (8, 9, 2) = 8.50 (exame ignorado)
-- ------------------------------------------------------------
CREATE FUNCTION fn_calcular_media(
    p_n1    DECIMAL(4,2),
    p_n2    DECIMAL(4,2),
    p_exame DECIMAL(4,2)
)
RETURNS DECIMAL(4,2)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_parcial DECIMAL(4,2);

    IF p_n1 IS NULL OR p_n2 IS NULL THEN
        RETURN NULL;
    END IF;

    SET v_parcial = ROUND((p_n1 + p_n2) / 2, 2);

    IF p_exame IS NOT NULL AND v_parcial >= 4 AND v_parcial < 7 THEN
        RETURN ROUND((v_parcial + p_exame) / 2, 2);
    END IF;

    RETURN v_parcial;
END$$

-- ------------------------------------------------------------
-- fn_frequencia_calc(p_faltas, p_total_aulas)  ->  DECIMAL(5,2)
-- Auxiliar: mesma fórmula da fn_frequencia, mas recebendo os valores.
-- Existe para o trigger BEFORE UPDATE poder calcular com NEW.* (a
-- fn_frequencia(id) leria a linha antiga da tabela) e para as views
-- não fazerem um SELECT a mais por linha.
--
--   (total_aulas - faltas) / total_aulas * 100, truncado em 2 casas
--   total_aulas NULL ou 0 -> NULL | mais faltas que aulas -> 0.00
-- ------------------------------------------------------------
CREATE FUNCTION fn_frequencia_calc(
    p_faltas      INT,
    p_total_aulas INT
)
RETURNS DECIMAL(5,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_total_aulas IS NULL OR p_total_aulas <= 0 THEN
        RETURN NULL;
    END IF;

    RETURN TRUNCATE(
        GREATEST(p_total_aulas - COALESCE(p_faltas, 0), 0) * 100 / p_total_aulas,
        2);
END$$

-- ------------------------------------------------------------
-- fn_frequencia(p_id_matricula)  ->  DECIMAL(5,2)
-- Porcentagem de presença da matrícula:
--   (total_aulas - faltas) / total_aulas * 100
-- total_aulas vem da turma; faltas, da matrícula.
-- Matrícula inexistente -> NULL.
-- ------------------------------------------------------------
CREATE FUNCTION fn_frequencia(p_id_matricula INT)
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE v_faltas      INT;
    DECLARE v_total_aulas INT;

    SELECT m.faltas, t.total_aulas
      INTO v_faltas, v_total_aulas
      FROM matricula m
      JOIN turma t ON t.id_turma = m.id_turma
     WHERE m.id_matricula = p_id_matricula;

    RETURN fn_frequencia_calc(v_faltas, v_total_aulas);
END$$

-- ------------------------------------------------------------
-- fn_situacao_calc(p_n1, p_n2, p_exame, p_faltas, p_total_aulas)
--   ->  VARCHAR(19)
-- Auxiliar com TODA a regra de situação (RN02, RN03 e RN04) em um
-- lugar só. É chamada pela fn_situacao e pelos triggers.
--
--   frequência < 75%           -> 'Reprovado por Falta'   (RN04)
--   falta N1 ou N2             -> 'Cursando'
--   parcial >= 7,00            -> 'Aprovado'              (RN02)
--   parcial <  4,00            -> 'Reprovado por Nota'    (RN02)
--   4,00 a 6,99, sem exame     -> 'Em Exame'              (RN02)
--   (parcial + exame)/2 >= 5   -> 'Aprovado'              (RN03)
--   senão                      -> 'Reprovado por Nota'    (RN03)
-- ------------------------------------------------------------
CREATE FUNCTION fn_situacao_calc(
    p_n1          DECIMAL(4,2),
    p_n2          DECIMAL(4,2),
    p_exame       DECIMAL(4,2),
    p_faltas      INT,
    p_total_aulas INT
)
RETURNS VARCHAR(19)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_frequencia DECIMAL(5,2);
    DECLARE v_parcial    DECIMAL(4,2);

    -- RN04: reprovação por falta independe das notas
    SET v_frequencia = fn_frequencia_calc(p_faltas, p_total_aulas);
    IF v_frequencia IS NOT NULL AND v_frequencia < 75 THEN
        RETURN 'Reprovado por Falta';
    END IF;

    IF p_n1 IS NULL OR p_n2 IS NULL THEN
        RETURN 'Cursando';
    END IF;

    -- RN01 / RN02
    SET v_parcial = ROUND((p_n1 + p_n2) / 2, 2);

    IF v_parcial >= 7 THEN
        RETURN 'Aprovado';
    END IF;

    IF v_parcial < 4 THEN
        RETURN 'Reprovado por Nota';
    END IF;

    IF p_exame IS NULL THEN
        RETURN 'Em Exame';
    END IF;

    -- RN03: a média final já sai certa da fn_calcular_media
    IF fn_calcular_media(p_n1, p_n2, p_exame) >= 5 THEN
        RETURN 'Aprovado';
    END IF;

    RETURN 'Reprovado por Nota';
END$$

-- ------------------------------------------------------------
-- fn_situacao(p_id_matricula)  ->  VARCHAR(19)
-- Situação da matrícula combinando RN02, RN03 e RN04.
-- Só busca a linha e chama a fn_situacao_calc.
-- Matrícula inexistente -> NULL.
-- ------------------------------------------------------------
CREATE FUNCTION fn_situacao(p_id_matricula INT)
RETURNS VARCHAR(19)
READS SQL DATA
BEGIN
    DECLARE v_n1          DECIMAL(4,2);
    DECLARE v_n2          DECIMAL(4,2);
    DECLARE v_exame       DECIMAL(4,2);
    DECLARE v_faltas      INT;
    DECLARE v_total_aulas INT;
    DECLARE v_achou       INT DEFAULT 0;

    SELECT m.n1, m.n2, m.exame, m.faltas, t.total_aulas, 1
      INTO v_n1, v_n2, v_exame, v_faltas, v_total_aulas, v_achou
      FROM matricula m
      JOIN turma t ON t.id_turma = m.id_turma
     WHERE m.id_matricula = p_id_matricula;

    IF v_achou = 0 THEN
        RETURN NULL;
    END IF;

    RETURN fn_situacao_calc(v_n1, v_n2, v_exame, v_faltas, v_total_aulas);
END$$

-- ------------------------------------------------------------
-- fn_cr_aluno(p_id_aluno)  ->  DECIMAL(4,2)        (opcional)
-- Coeficiente de Rendimento ponderado pela carga horária:
--   CR = SOMA(média final x carga horária) / SOMA(carga horária)
--
-- Entram só as disciplinas já concluídas ('Aprovado', 'Reprovado por
-- Nota' e 'Reprovado por Falta'). 'Cursando' e 'Em Exame' ficam de
-- fora porque ainda não têm resultado. Reprovação por falta sem nota
-- lançada conta como média 0.
-- Aluno sem disciplina concluída -> NULL.
-- ------------------------------------------------------------
CREATE FUNCTION fn_cr_aluno(p_id_aluno INT)
RETURNS DECIMAL(4,2)
READS SQL DATA
BEGIN
    DECLARE v_cr DECIMAL(4,2);

    SELECT ROUND(SUM(COALESCE(m.media_final, 0) * d.carga_horaria)
                 / SUM(d.carga_horaria), 2)
      INTO v_cr
      FROM matricula m
      JOIN turma t      ON t.id_turma = m.id_turma
      JOIN disciplina d ON d.id_disciplina = t.id_disciplina
     WHERE m.id_aluno = p_id_aluno
       AND m.situacao IN ('Aprovado', 'Reprovado por Nota', 'Reprovado por Falta');

    RETURN v_cr;
END$$

DELIMITER ;


-- ============================================================
-- VIEWS
-- ============================================================

-- ------------------------------------------------------------
-- vw_boletim
-- Uma linha por matrícula. Colunas do enunciado: aluno, ra,
-- disciplina, semestre, n1, n2, exame, media_final, faltas, situacao.
-- Além do mínimo (combinado do grupo): id_matricula e id_turma, para
-- a tela de lançar notas saber qual matrícula está editando; e
-- id_aluno, total_aulas e frequencia, para filtrar e exibir.
--
-- Uso:  SELECT * FROM vw_boletim WHERE id_aluno = ? ORDER BY semestre;
--       SELECT * FROM vw_boletim WHERE id_turma = ? ORDER BY aluno;
-- ------------------------------------------------------------
CREATE VIEW vw_boletim AS
SELECT m.id_matricula,
       m.id_turma,
       a.id_aluno,
       a.nome        AS aluno,
       a.ra,
       d.nome        AS disciplina,
       t.semestre,
       m.n1,
       m.n2,
       m.exame,
       m.media_final,
       m.faltas,
       t.total_aulas,
       fn_frequencia_calc(m.faltas, t.total_aulas) AS frequencia,
       m.situacao
  FROM matricula m
  JOIN aluno a      ON a.id_aluno = m.id_aluno
  JOIN turma t      ON t.id_turma = m.id_turma
  JOIN disciplina d ON d.id_disciplina = t.id_disciplina;

-- ------------------------------------------------------------
-- vw_turmas_lotacao
-- Uma linha por turma (inclusive as que não têm ninguém matriculado):
-- vagas totais, matriculados, vagas restantes e % de ocupação.
-- Além do mínimo: semestre e status, para a tela de matrícula listar
-- só as turmas 'Aberta' do semestre.
--
-- Uso:  SELECT * FROM vw_turmas_lotacao WHERE status = 'Aberta';
-- ------------------------------------------------------------
CREATE VIEW vw_turmas_lotacao AS
SELECT t.id_turma,
       d.nome                           AS disciplina,
       p.nome                           AS professor,
       t.semestre,
       t.status,
       t.vagas,
       COUNT(m.id_matricula)            AS matriculados,
       t.vagas - COUNT(m.id_matricula)  AS vagas_restantes,
       ROUND(COUNT(m.id_matricula) * 100 / t.vagas, 2) AS perc_ocupacao
  FROM turma t
  JOIN disciplina d     ON d.id_disciplina = t.id_disciplina
  JOIN professor p      ON p.id_professor = t.id_professor
  LEFT JOIN matricula m ON m.id_turma = t.id_turma
 GROUP BY t.id_turma, d.nome, p.nome, t.semestre, t.status, t.vagas;

-- ------------------------------------------------------------
-- vw_desempenho_turma
-- Uma linha por turma: média global, maior e menor nota (sobre a
-- media_final dos alunos que já têm média), % de aprovados e % de
-- reprovados (por nota + por falta).
-- Os percentuais são sobre o total de matriculados da turma, então
-- aprovados + reprovados só fecha 100% quando ninguém mais está
-- 'Cursando' ou 'Em Exame' (por isso a coluna perc_em_andamento).
-- Turma sem matrícula: contagens 0 e o resto NULL.
-- ------------------------------------------------------------
CREATE VIEW vw_desempenho_turma AS
SELECT t.id_turma,
       d.nome                        AS disciplina,
       p.nome                        AS professor,
       t.semestre,
       COUNT(m.id_matricula)         AS matriculados,
       ROUND(AVG(m.media_final), 2)  AS media_turma,
       MAX(m.media_final)            AS maior_nota,
       MIN(m.media_final)            AS menor_nota,
       ROUND(COALESCE(SUM(m.situacao = 'Aprovado'), 0) * 100
             / NULLIF(COUNT(m.id_matricula), 0), 2) AS perc_aprovados,
       ROUND(COALESCE(SUM(m.situacao IN ('Reprovado por Nota', 'Reprovado por Falta')), 0) * 100
             / NULLIF(COUNT(m.id_matricula), 0), 2) AS perc_reprovados,
       ROUND(COALESCE(SUM(m.situacao IN ('Cursando', 'Em Exame')), 0) * 100
             / NULLIF(COUNT(m.id_matricula), 0), 2) AS perc_em_andamento
  FROM turma t
  JOIN disciplina d     ON d.id_disciplina = t.id_disciplina
  JOIN professor p      ON p.id_professor = t.id_professor
  LEFT JOIN matricula m ON m.id_turma = t.id_turma
 GROUP BY t.id_turma, d.nome, p.nome, t.semestre;

-- ------------------------------------------------------------
-- vw_faturamento_curso                       (além do mínimo)
-- Faturamento mensal previsto por curso, para o relatório financeiro
-- do Coordenador: alunos com status 'Ativo' x valor_mensalidade.
-- Trancados e formados não pagam mensalidade, então não entram.
-- Curso sem aluno ativo aparece com 0.
-- ------------------------------------------------------------
CREATE VIEW vw_faturamento_curso AS
SELECT c.id_curso,
       c.nome                                  AS curso,
       c.turno,
       c.valor_mensalidade,
       COUNT(a.id_aluno)                       AS alunos_ativos,
       COUNT(a.id_aluno) * c.valor_mensalidade AS faturamento_mensal
  FROM curso c
  LEFT JOIN aluno a ON a.id_curso = c.id_curso
                   AND a.status = 'Ativo'
 GROUP BY c.id_curso, c.nome, c.turno, c.valor_mensalidade;


-- ============================================================
-- TRIGGERS (todos na tabela matricula)
-- ============================================================
DELIMITER $$

-- ------------------------------------------------------------
-- trg_valida_vagas  (BEFORE INSERT)                       RN05
-- Bloqueia a matrícula quando a turma já está com todas as vagas
-- ocupadas. Vale para qualquer INSERT, inclusive os da massa de
-- dados e os feitos fora da sp_matricular_aluno.
--
-- O SELECT ... FOR UPDATE trava a linha da turma até o fim da
-- transação: duas matrículas simultâneas na última vaga entram em
-- fila, e a segunda já enxerga a turma lotada.
-- ------------------------------------------------------------
CREATE TRIGGER trg_valida_vagas
BEFORE INSERT ON matricula
FOR EACH ROW
BEGIN
    DECLARE v_vagas        INT;
    DECLARE v_matriculados INT;
    DECLARE v_msg          VARCHAR(128);

    SELECT vagas
      INTO v_vagas
      FROM turma
     WHERE id_turma = NEW.id_turma
       FOR UPDATE;

    -- Turma inexistente: v_vagas fica NULL e quem recusa é a FK.
    IF v_vagas IS NOT NULL THEN
        SELECT COUNT(*)
          INTO v_matriculados
          FROM matricula
         WHERE id_turma = NEW.id_turma;

        IF v_matriculados >= v_vagas THEN
            SET v_msg = CONCAT('Turma lotada: a turma ', NEW.id_turma,
                               ' já tem ', v_matriculados, ' de ', v_vagas,
                               ' vagas ocupadas.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;
END$$

-- ------------------------------------------------------------
-- trg_situacao_inicial  (BEFORE INSERT)          (além do mínimo)
-- Calcula media_final e situacao também na inserção. Sem ele, uma
-- matrícula inserida já com notas (a massa de dados do semestre
-- encerrado, por exemplo) ficaria 'Cursando' e sem média até o
-- primeiro UPDATE. O que vier em media_final/situacao no INSERT é
-- substituído pelo valor calculado.
-- FOLLOWS: roda depois do trg_valida_vagas.
-- ------------------------------------------------------------
CREATE TRIGGER trg_situacao_inicial
BEFORE INSERT ON matricula
FOR EACH ROW
FOLLOWS trg_valida_vagas
BEGIN
    DECLARE v_total_aulas INT;

    SELECT total_aulas
      INTO v_total_aulas
      FROM turma
     WHERE id_turma = NEW.id_turma;

    SET NEW.media_final = fn_calcular_media(NEW.n1, NEW.n2, NEW.exame);
    SET NEW.situacao    = fn_situacao_calc(NEW.n1, NEW.n2, NEW.exame,
                                           NEW.faltas, v_total_aulas);
END$$

-- ------------------------------------------------------------
-- trg_atualiza_situacao  (BEFORE UPDATE)              RN01 a RN04
-- Recalcula media_final e situacao sempre que n1, n2, exame, faltas
-- ou a turma mudam. Quem lança nota só precisa dar UPDATE nas notas:
-- a média e a situação saem daqui.
--
-- Usa NEW.* com as functions auxiliares, porque dentro de um BEFORE
-- UPDATE a fn_situacao(id) ainda leria os valores antigos da tabela.
--
-- Se o UPDATE não mexe em nota, falta nem turma, o trigger não
-- recalcula. Isso deixa a sp_fechar_semestre gravar uma situação de
-- fechamento (ex.: 'Em Exame' sem exame -> 'Reprovado por Nota').
-- ------------------------------------------------------------
CREATE TRIGGER trg_atualiza_situacao
BEFORE UPDATE ON matricula
FOR EACH ROW
BEGIN
    DECLARE v_total_aulas INT;

    IF NOT (OLD.n1 <=> NEW.n1)
       OR NOT (OLD.n2 <=> NEW.n2)
       OR NOT (OLD.exame <=> NEW.exame)
       OR NOT (OLD.faltas <=> NEW.faltas)
       OR NOT (OLD.id_turma <=> NEW.id_turma) THEN

        SELECT total_aulas
          INTO v_total_aulas
          FROM turma
         WHERE id_turma = NEW.id_turma;

        SET NEW.media_final = fn_calcular_media(NEW.n1, NEW.n2, NEW.exame);
        SET NEW.situacao    = fn_situacao_calc(NEW.n1, NEW.n2, NEW.exame,
                                               NEW.faltas, v_total_aulas);
    END IF;
END$$

-- ------------------------------------------------------------
-- trg_auditoria_nota  (AFTER UPDATE)                      RN08
-- Grava em log_nota uma linha por campo alterado: n1, n2, exame e
-- faltas (as faltas entram porque também mudam a situação).
-- O usuário vem de NEW.id_usuario: quem altera nota precisa gravar o
-- próprio id na matrícula, no mesmo UPDATE.
-- O <=> compara tratando NULL: de NULL para 7.5 conta como alteração,
-- e de NULL para NULL não.
-- ------------------------------------------------------------
CREATE TRIGGER trg_auditoria_nota
AFTER UPDATE ON matricula
FOR EACH ROW
BEGIN
    IF NOT (OLD.n1 <=> NEW.n1) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'n1', OLD.n1, NEW.n1, NEW.id_usuario);
    END IF;

    IF NOT (OLD.n2 <=> NEW.n2) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'n2', OLD.n2, NEW.n2, NEW.id_usuario);
    END IF;

    IF NOT (OLD.exame <=> NEW.exame) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'exame', OLD.exame, NEW.exame, NEW.id_usuario);
    END IF;

    IF NOT (OLD.faltas <=> NEW.faltas) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'faltas', OLD.faltas, NEW.faltas, NEW.id_usuario);
    END IF;
END$$

DELIMITER ;

DELIMITER ;
-- <<< FIM DE 02a_functions_views_triggers.sql


-- ============================================================
-- >>> INICIO DE 02b_procedures.sql
-- ============================================================

-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 02b_procedures.sql: stored procedures do enunciado
-- Responsável: Mykael
-- ============================================================
-- Ordem de execução (ver README):
--   01_ddl -> 02a_functions_views_triggers -> 02b_procedures
--   -> 02c_procedures_cadastro -> 03_dados -> 04_testes
--
-- Depende do 01_ddl.sql (tabelas) e do 02a (vw_boletim e os triggers
-- que calculam media_final e situacao). Pode rodar de novo quantas
-- vezes quiser: cada procedure tem o seu DROP ... IF EXISTS.
--
-- O que tem aqui:
--   sp_LoginUsuario      devolve id, nome, e-mail e perfil (nunca a senha)
--   sp_matricular_aluno  RN05, RN06 e RN09
--   sp_lancar_notas      n1, n2 e faltas (só Coordenador)
--   sp_lancar_exame      só se a situação for 'Em Exame' (só Coordenador)
--   sp_historico_aluno   boletim do aluno, ordenado por semestre
--   sp_fechar_semestre   cursor + transação (só Coordenador)
--
-- Combinados do grupo usados aqui:
--   * Regra quebrada vira SIGNAL SQLSTATE '45000' com MESSAGE_TEXT
--     legível: a interface só mostra essa mensagem.
--   * Perfis com a grafia exata: 'Secretario' e 'Coordenador'.
--   * Senha: SHA-256 em hexadecimal minúsculo (a interface calcula o
--     hash e manda para a sp_LoginUsuario).
--   * Prefixos sp_ vw_; parâmetros p_, variáveis v_.
--
-- Decisões:
--   1. Média e situação NUNCA são calculadas aqui: as procedures só
--      gravam n1, n2, exame e faltas, e o trg_atualiza_situacao faz o
--      resto. Assim existe uma única fonte da regra.
--   2. Quem grava nota também grava o próprio id em matricula.id_usuario
--      no mesmo UPDATE, porque é daí que o trg_auditoria_nota tira o
--      usuário do log_nota (RN08).
--   3. Notas fora de 0 a 10 não são conferidas aqui: quem barra é o
--      CHECK do DDL (RN07).
--   4. Só se matricula em turma 'Aberta' e só se lançam notas em turma
--      'Aberta': depois do fechamento a situação é definitiva.
--   5. Lançar notas e exame exige Coordenador (o Secretário não tem
--      acesso a notas nem a fechamento).
-- ============================================================

USE sga_fbi;

DROP PROCEDURE IF EXISTS sp_fechar_semestre;
DROP PROCEDURE IF EXISTS sp_historico_aluno;
DROP PROCEDURE IF EXISTS sp_lancar_exame;
DROP PROCEDURE IF EXISTS sp_lancar_notas;
DROP PROCEDURE IF EXISTS sp_matricular_aluno;
DROP PROCEDURE IF EXISTS sp_LoginUsuario;

DELIMITER $$

-- ------------------------------------------------------------
-- sp_LoginUsuario
-- Devolve uma linha (id_usuario, nome, email, perfil) se login e hash
-- conferem; senão devolve o resultado vazio. Nunca devolve a senha e
-- não diz se foi o login ou a senha que errou.
-- A comparação é por bytes (utf8mb4_bin): login diferencia maiúscula
-- de minúscula e o hash tem que ser o hexadecimal minúsculo.
--
-- Uso:  CALL sp_LoginUsuario('coord.ana', SHA2('Senha@123', 256));
-- ------------------------------------------------------------
CREATE PROCEDURE sp_LoginUsuario(
    IN p_login       VARCHAR(30),
    IN p_senha_hash  CHAR(64)
)
BEGIN
    SELECT id_usuario, nome, email, perfil
      FROM usuario
     WHERE login      COLLATE utf8mb4_bin = p_login
       AND senha_hash COLLATE utf8mb4_bin = p_senha_hash;
END$$

-- ------------------------------------------------------------
-- sp_matricular_aluno                              RN05, RN06, RN09
-- Cria a matrícula e devolve uma linha com o id_matricula.
--   RN09  aluno 'Trancado' ou 'Formado' não se matricula
--   RN06  só com 'Aprovado' em todos os pré-requisitos da disciplina
--   RN05  a turma não pode passar das vagas (quem barra é o
--         trg_valida_vagas, que trava a turma e evita corrida na
--         última vaga)
-- Além do mínimo: turma precisa estar 'Aberta', o aluno não pode já
-- estar matriculado na turma e não pode se matricular de novo numa
-- disciplina em que já foi 'Aprovado' (quem reprovou pode repetir).
--
-- Uso:  CALL sp_matricular_aluno(10, 4, 3);
-- Erros (45000): aluno, turma ou usuário inexistente; aluno não
--   'Ativo'; turma encerrada; já matriculado; já aprovado na
--   disciplina; falta pré-requisito; turma lotada.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_matricular_aluno(
    IN p_id_aluno    INT,
    IN p_id_turma    INT,
    IN p_id_usuario  INT
)
BEGIN
    DECLARE v_status_aluno  VARCHAR(8);
    DECLARE v_status_turma  VARCHAR(9);
    DECLARE v_id_disciplina INT;
    DECLARE v_faltando      VARCHAR(100);
    DECLARE v_msg           VARCHAR(128);

    IF NOT EXISTS (SELECT 1 FROM usuario WHERE id_usuario = p_id_usuario) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário não encontrado.';
    END IF;

    SELECT status INTO v_status_aluno FROM aluno WHERE id_aluno = p_id_aluno;
    IF v_status_aluno IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno não encontrado.';
    END IF;

    SELECT status, id_disciplina
      INTO v_status_turma, v_id_disciplina
      FROM turma
     WHERE id_turma = p_id_turma;
    IF v_status_turma IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma não encontrada.';
    END IF;

    IF v_status_aluno COLLATE utf8mb4_bin <> 'Ativo' THEN
        SET v_msg = CONCAT('Aluno ', v_status_aluno,
                           ' não pode se matricular: só alunos Ativos.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_status_turma COLLATE utf8mb4_bin <> 'Aberta' THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Turma encerrada: não aceita novas matrículas.';
    END IF;

    IF EXISTS (SELECT 1 FROM matricula
                WHERE id_aluno = p_id_aluno AND id_turma = p_id_turma) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno já matriculado nesta turma.';
    END IF;

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
    IF v_faltando IS NOT NULL THEN
        SET v_msg = CONCAT('Falta pré-requisito: o aluno não foi aprovado em ',
                           v_faltando, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    INSERT INTO matricula (id_aluno, id_turma, id_usuario)
    VALUES (p_id_aluno, p_id_turma, p_id_usuario);

    SELECT LAST_INSERT_ID() AS id_matricula;
END$$

-- ------------------------------------------------------------
-- sp_lancar_notas
-- Grava n1, n2 e faltas da matrícula e o id de quem lançou. A média e
-- a situação saem do trg_atualiza_situacao, e a alteração vai para o
-- log_nota pelo trg_auditoria_nota. n1 ou n2 podem vir NULL só enquanto
-- aquela nota ainda não existe (dá para lançar a N1 antes da N2); uma
-- nota já lançada não pode ser apagada, só trocada por outro valor.
-- Notas fora de 0 a 10 são barradas pelo CHECK (RN07).
--
-- Uso:  CALL sp_lancar_notas(20, 7.0, 8.0, 3, 1);
-- Erros (45000): usuário não é Coordenador; matrícula inexistente;
--   turma encerrada; tentativa de apagar nota já lançada; faltas em
--   branco ou negativas.
-- ------------------------------------------------------------
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

    SELECT perfil INTO v_perfil FROM usuario WHERE id_usuario = p_id_usuario;
    IF v_perfil IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário não encontrado.';
    END IF;
    IF v_perfil COLLATE utf8mb4_bin <> 'Coordenador' THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Apenas o Coordenador pode lançar notas.';
    END IF;

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

    IF (p_n1 IS NULL AND v_n1_atual IS NOT NULL)
       OR (p_n2 IS NULL AND v_n2_atual IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Não é possível apagar uma nota já lançada: informe o novo valor.';
    END IF;

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

-- ------------------------------------------------------------
-- sp_lancar_exame
-- Grava a nota do exame, mas só quando a matrícula está 'Em Exame'.
-- O resultado final (RN03) sai do trg_atualiza_situacao: média final
-- >= 5,0 vira 'Aprovado'; senão, 'Reprovado por Nota'.
--
-- Uso:  CALL sp_lancar_exame(18, 5.0, 1);
-- Erros (45000): usuário não é Coordenador; matrícula inexistente;
--   situação diferente de 'Em Exame'; exame em branco.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_lancar_exame(
    IN p_id_matricula  INT,
    IN p_exame         DECIMAL(4,2),
    IN p_id_usuario    INT
)
BEGIN
    DECLARE v_perfil    VARCHAR(11);
    DECLARE v_situacao  VARCHAR(19);
    DECLARE v_msg       VARCHAR(128);

    SELECT perfil INTO v_perfil FROM usuario WHERE id_usuario = p_id_usuario;
    IF v_perfil IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário não encontrado.';
    END IF;
    IF v_perfil COLLATE utf8mb4_bin <> 'Coordenador' THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Apenas o Coordenador pode lançar exame.';
    END IF;

    SELECT situacao INTO v_situacao FROM matricula WHERE id_matricula = p_id_matricula;
    IF v_situacao IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Matrícula não encontrada.';
    END IF;
    IF v_situacao COLLATE utf8mb4_bin <> 'Em Exame' THEN
        SET v_msg = CONCAT('Exame só pode ser lançado para matrícula Em Exame; a situação atual é ',
                           v_situacao, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF p_exame IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe a nota do exame.';
    END IF;

    UPDATE matricula
       SET exame      = p_exame,
           id_usuario = p_id_usuario
     WHERE id_matricula = p_id_matricula;
END$$

-- ------------------------------------------------------------
-- sp_historico_aluno
-- Todas as matrículas do aluno, ordenadas por semestre e disciplina.
--
-- Uso:  CALL sp_historico_aluno(1);
-- Erros (45000): aluno inexistente.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_historico_aluno(IN p_id_aluno INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM aluno WHERE id_aluno = p_id_aluno) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno não encontrado.';
    END IF;

    SELECT semestre, disciplina, n1, n2, exame, media_final,
           faltas, frequencia, situacao
      FROM vw_boletim
     WHERE id_aluno = p_id_aluno
     ORDER BY semestre, disciplina;
END$$

-- ------------------------------------------------------------
-- sp_fechar_semestre
-- Encerra as turmas 'Aberta' do semestre e fecha a situação de cada
-- matrícula, tudo ou nada:
--   'Em Exame' sem exame lançado -> 'Reprovado por Nota'
--   'Cursando' (falta N1 ou N2)  -> o fechamento é recusado e nada
--                                   muda (ROLLBACK): lance as notas.
-- As demais situações já são definitivas. Devolve a contagem de
-- matrículas do semestre por situação.
--
-- As conferências de perfil e de formato vêm antes do START
-- TRANSACTION, então um Secretário barrado não mexe em nada.
--
-- Uso:  CALL sp_fechar_semestre('2026.2', 1);
-- Erros (45000): usuário não é Coordenador; semestre fora do
--   formato 'AAAA.S'; semestre sem turma aberta; matrícula sem notas.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_fechar_semestre(
    IN p_semestre    CHAR(6),
    IN p_id_usuario  INT
)
BEGIN
    DECLARE v_perfil VARCHAR(11);

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

    BEGIN
        DECLARE v_fim           INT DEFAULT 0;
        DECLARE v_abertas       INT;
        DECLARE v_id_matricula  INT;
        DECLARE v_situacao      VARCHAR(19);
        DECLARE v_aluno         VARCHAR(100);
        DECLARE v_msg           VARCHAR(128);

        DECLARE cur_matriculas CURSOR FOR
            SELECT m.id_matricula, m.situacao, a.nome
              FROM matricula m
              JOIN turma t ON t.id_turma = m.id_turma
              JOIN aluno a ON a.id_aluno = m.id_aluno
             WHERE t.semestre = p_semestre
               AND t.status   = 'Aberta'
               AND m.situacao IN ('Cursando', 'Em Exame')
             ORDER BY m.id_matricula;

        DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim = 1;
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;

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

        OPEN cur_matriculas;
        ler: LOOP
            FETCH cur_matriculas INTO v_id_matricula, v_situacao, v_aluno;
            IF v_fim = 1 THEN
                LEAVE ler;
            END IF;

            IF v_situacao = 'Cursando' THEN
                SET v_msg = CONCAT('Matrícula ', v_id_matricula, ' (', v_aluno,
                                   ') sem N1 ou N2: lance as notas antes de fechar o semestre.');
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
            END IF;

            UPDATE matricula
               SET situacao   = 'Reprovado por Nota',
                   id_usuario = p_id_usuario
             WHERE id_matricula = v_id_matricula;
        END LOOP;
        CLOSE cur_matriculas;

        UPDATE turma
           SET status = 'Encerrada'
         WHERE semestre = p_semestre
           AND status   = 'Aberta';

        COMMIT;
    END;

    SELECT situacao, COUNT(*) AS total
      FROM vw_boletim
     WHERE semestre = p_semestre
     GROUP BY situacao
     ORDER BY situacao;
END$$

DELIMITER ;

DELIMITER ;
-- <<< FIM DE 02b_procedures.sql


-- ============================================================
-- >>> INICIO DE 02c_procedures_cadastro.sql
-- ============================================================

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
--   vw_cr_aluno         CR (fn_cr_aluno) de cada aluno, para histórico e boletim
--   vw_log_nota         auditoria de notas (RN08) legível, para a tela do Coordenador
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
DROP VIEW IF EXISTS vw_log_nota;
DROP VIEW IF EXISTS vw_cr_aluno;
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


-- ------------------------------------------------------------
-- vw_cr_aluno
-- Uma linha por aluno com o Coeficiente de Rendimento calculado pela
-- fn_cr_aluno (média final ponderada pela carga horária, só das
-- disciplinas concluídas). Aluno sem disciplina concluída aparece
-- com cr NULL: a interface mostra "sem disciplinas concluídas".
--
-- Uso:  SELECT cr FROM vw_cr_aluno WHERE id_aluno = ?;
-- ------------------------------------------------------------
CREATE VIEW vw_cr_aluno AS
SELECT a.id_aluno,
       a.nome AS aluno,
       a.ra,
       fn_cr_aluno(a.id_aluno) AS cr
  FROM aluno a;

-- ------------------------------------------------------------
-- vw_log_nota
-- Auditoria de notas (RN08) em forma legível: cada linha do log_nota
-- (gravada pelo trg_auditoria_nota) com o aluno, a disciplina, o
-- semestre e o nome de quem alterou. A ordenação (mais recente
-- primeiro) fica na consulta: ORDER BY data_hora DESC, id_log DESC.
-- Só o Coordenador acessa a tela que lê esta view.
--
-- Uso:  SELECT * FROM vw_log_nota ORDER BY data_hora DESC, id_log DESC LIMIT 500;
-- ------------------------------------------------------------
CREATE VIEW vw_log_nota AS
SELECT l.id_log,
       l.id_matricula,
       a.nome       AS aluno,
       a.ra,
       d.nome       AS disciplina,
       t.semestre,
       l.campo,
       l.valor_antigo,
       l.valor_novo,
       u.nome       AS usuario,
       l.data_hora
  FROM log_nota l
  JOIN matricula m  ON m.id_matricula = l.id_matricula
  JOIN aluno a      ON a.id_aluno = m.id_aluno
  JOIN turma t      ON t.id_turma = m.id_turma
  JOIN disciplina d ON d.id_disciplina = t.id_disciplina
  JOIN usuario u    ON u.id_usuario = l.usuario;


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

DELIMITER ;
-- <<< FIM DE 02c_procedures_cadastro.sql


-- ============================================================
-- >>> INICIO DE 03_dados.sql
-- ============================================================

-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 03_dados.sql: massa de dados de exemplo
-- Responsável: Guilherme
-- ============================================================
-- Roda DEPOIS da programação (02a, 02b, 02c), com os triggers
-- ativos: se o trg_valida_vagas reclamar, a massa está errada.
--
-- Os IDs abaixo valem só se o banco acabou de ser criado pelo
-- 01_ddl.sql (o AUTO_INCREMENT começa do 1). Para recarregar a massa,
-- rode o SGA_completo.sql do zero.
--
-- LOGINS DE TESTE (todas as senhas: Senha@123)
--   Coordenador  coord.ana       (id_usuario 1)
--   Coordenador  coord.bruno     (id_usuario 2)
--   Secretario   sec.carla       (id_usuario 3)  <- grava as matrículas
--   Secretario   sec.diego       (id_usuario 4)
--   Secretario   sec.elisa       (id_usuario 5)
--
-- CENÁRIOS DE TESTE (para o 04_testes.sql)
--   Teste 2  turma lotada ........ turma 3 (POO 2026.2): 4 vagas, 4
--            matriculados. O aluno 5 (ADS, Ativo, aprovado em Lógica)
--            tenta se matricular e só a falta de vaga o barra.
--   Teste 3  sem pré-requisito ... turma 5 (Estruturas de Dados
--            2026.2): 8 vagas, 6 matriculados, pré-requisito
--            Algoritmos. O aluno 16 (CC, Ativo) foi 'Reprovado por
--            Nota' em Algoritmos e é barrado só pelo pré-requisito.
--            O aluno 9 (ADS, Ativo, nunca cursou Lógica) em POO
--            (turma 3) também é barrado; a turma 3 já está lotada.
--   Teste 4  aluno Trancado ...... aluno 19 (Trancado)
--            aluno Formado ....... aluno 20 (Formado)
--   Teste 6  cai em Em Exame ..... matrícula 18 (aluno 2, turma 3):
--            N1 6,0 e N2 7,0 (parcial 6,5). Lançar o exame e conferir
--            a situação final.
--   Teste 7  média >= 9 e faltas > 25% ... matrícula 19 (aluno 3,
--            turma 3): N1 9,5, N2 9,5 e 25 faltas em 80 aulas
--            -> 'Reprovado por Falta'.
--   Teste 8  log_nota ............ qualquer UPDATE de nota, por
--            exemplo na matrícula 17 (aluno 1, turma 3).
--   Histórico: semestre 2026.1 (turmas 1 e 2, Encerradas) com todos os
--   desfechos possíveis; semestre 2026.2 (turmas 3, 4 e 5, Abertas).
--
-- Mínimo exigido e o que tem aqui:
--   5 usuários (2 Coordenadores + 3 Secretários, senhas em hash)
--   3 cursos | 6 disciplinas | 5 professores
--   20 alunos | 5 turmas | 35 matrículas
--
-- CPFs e e-mails são fictícios.
-- ============================================================

USE sga_fbi;

-- ------------------------------------------------------------
-- usuario
-- ------------------------------------------------------------
INSERT INTO usuario (nome, cpf, email, login, senha_hash, perfil) VALUES
('Ana Beatriz Moura',   '10000000001', 'ana.moura@fbi.edu.br',     'coord.ana',   SHA2('Senha@123', 256), 'Coordenador'),
('Bruno Tavares',       '10000000002', 'bruno.tavares@fbi.edu.br', 'coord.bruno', SHA2('Senha@123', 256), 'Coordenador'),
('Carla Nogueira',      '10000000003', 'carla.nogueira@fbi.edu.br','sec.carla',   SHA2('Senha@123', 256), 'Secretario'),
('Diego Albuquerque',   '10000000004', 'diego.alb@fbi.edu.br',     'sec.diego',   SHA2('Senha@123', 256), 'Secretario'),
('Elisa Fontes',        '10000000005', 'elisa.fontes@fbi.edu.br',  'sec.elisa',   SHA2('Senha@123', 256), 'Secretario');

-- ------------------------------------------------------------
-- curso
-- ------------------------------------------------------------
INSERT INTO curso (nome, carga_horaria_total, turno, valor_mensalidade) VALUES
('Análise e Desenvolvimento de Sistemas', 2000, 'Noturno',    650.00),
('Ciência da Computação',                 3200, 'Matutino',  1200.00),
('Sistemas de Informação',                2800, 'Vespertino', 980.00);

-- ------------------------------------------------------------
-- disciplina (periodo = semestre da grade)
-- ------------------------------------------------------------
INSERT INTO disciplina (id_curso, nome, carga_horaria, periodo) VALUES
(1, 'Lógica de Programação',              80, 1),
(1, 'Programação Orientada a Objetos',    80, 2),
(1, 'Banco de Dados',                     60, 2),
(2, 'Algoritmos',                         80, 1),
(2, 'Estruturas de Dados',                70, 2),
(3, 'Introdução a Sistemas de Informação',40, 1);

-- POO exige Lógica; Estruturas de Dados exige Algoritmos
INSERT INTO pre_requisito (id_disciplina, id_disciplina_requisito) VALUES
(2, 1),
(5, 4);

-- ------------------------------------------------------------
-- professor
-- ------------------------------------------------------------
INSERT INTO professor (nome, cpf, email, titulacao, data_admissao) VALUES
('Marcos Vinícius Prado',  '20000000001', 'marcos.prado@fbi.edu.br',   'Doutor',       '2015-02-02'),
('Renata Campos Lima',     '20000000002', 'renata.lima@fbi.edu.br',    'Mestre',       '2018-08-01'),
('Paulo Henrique Sá',      '20000000003', 'paulo.sa@fbi.edu.br',       'Especialista', '2020-03-09'),
('Juliana Ferraz',         '20000000004', 'juliana.ferraz@fbi.edu.br', 'Mestre',       '2019-02-11'),
('Otávio Ramalho',         '20000000005', 'otavio.ramalho@fbi.edu.br', 'Graduado',     '2023-07-17');

-- ------------------------------------------------------------
-- aluno: 1-9 ADS | 10-16 Ciência da Computação | 17-20 Sistemas
-- de Informação (19 Trancado, 20 Formado)
-- ------------------------------------------------------------
INSERT INTO aluno (ra, nome, cpf, email, data_nascimento, id_curso, status) VALUES
('2025001', 'Alice Monteiro',       '30000000001', 'alice.monteiro@aluno.fbi.edu.br',   '2004-05-12', 1, 'Ativo'),
('2025002', 'Bernardo Cavalcante',  '30000000002', 'bernardo.cav@aluno.fbi.edu.br',     '2003-11-30', 1, 'Ativo'),
('2025003', 'Camila Rezende',       '30000000003', 'camila.rezende@aluno.fbi.edu.br',   '2005-01-22', 1, 'Ativo'),
('2025004', 'Daniel Pacheco',       '30000000004', 'daniel.pacheco@aluno.fbi.edu.br',   '2002-07-08', 1, 'Ativo'),
('2025005', 'Eduarda Siqueira',     '30000000005', 'eduarda.siqueira@aluno.fbi.edu.br', '2004-09-17', 1, 'Ativo'),
('2025006', 'Felipe Andrade',       '30000000006', 'felipe.andrade@aluno.fbi.edu.br',   '2003-03-03', 1, 'Ativo'),
('2025007', 'Gabriela Teixeira',    '30000000007', 'gabriela.teix@aluno.fbi.edu.br',    '2004-12-25', 1, 'Ativo'),
('2025008', 'Henrique Barros',      '30000000008', 'henrique.barros@aluno.fbi.edu.br',  '2001-06-14', 1, 'Ativo'),
('2026001', 'Isabela Carvalho',     '30000000009', 'isabela.carv@aluno.fbi.edu.br',     '2006-02-09', 1, 'Ativo'),
('2025101', 'João Pedro Lacerda',   '30000000010', 'joao.lacerda@aluno.fbi.edu.br',     '2004-04-04', 2, 'Ativo'),
('2025102', 'Karen Dutra',          '30000000011', 'karen.dutra@aluno.fbi.edu.br',      '2005-08-19', 2, 'Ativo'),
('2025103', 'Lucas Medeiros',       '30000000012', 'lucas.medeiros@aluno.fbi.edu.br',   '2003-10-01', 2, 'Ativo'),
('2025104', 'Marina Falcão',        '30000000013', 'marina.falcao@aluno.fbi.edu.br',    '2004-01-27', 2, 'Ativo'),
('2025105', 'Nicolas Brandão',      '30000000014', 'nicolas.brandao@aluno.fbi.edu.br',  '2002-12-12', 2, 'Ativo'),
('2025106', 'Olívia Guimarães',     '30000000015', 'olivia.guim@aluno.fbi.edu.br',      '2005-05-30', 2, 'Ativo'),
('2025107', 'Pedro Henrique Lopes', '30000000016', 'pedro.lopes@aluno.fbi.edu.br',      '2003-07-21', 2, 'Ativo'),
('2026201', 'Queila Macedo',        '30000000017', 'queila.macedo@aluno.fbi.edu.br',    '2006-03-15', 3, 'Ativo'),
('2026202', 'Rafael Domingues',     '30000000018', 'rafael.dom@aluno.fbi.edu.br',       '2005-11-05', 3, 'Ativo'),
('2024201', 'Sofia Peixoto',        '30000000019', 'sofia.peixoto@aluno.fbi.edu.br',    '2002-09-09', 3, 'Trancado'),
('2021201', 'Thiago Nascimento',    '30000000020', 'thiago.nasc@aluno.fbi.edu.br',      '1999-02-18', 3, 'Formado');

-- ------------------------------------------------------------
-- turma
--   1 Lógica 2026.1 | 2 Algoritmos 2026.1   (Encerradas)
--   3 POO 2026.2 (lotada) | 4 Banco de Dados 2026.2
--   5 Estruturas de Dados 2026.2             (Abertas)
-- ------------------------------------------------------------
INSERT INTO turma (id_disciplina, id_professor, semestre, vagas, total_aulas, status) VALUES
(1, 1, '2026.1', 10, 80, 'Encerrada'),
(4, 2, '2026.1', 10, 80, 'Encerrada'),
(2, 3, '2026.2',  4, 80, 'Aberta'),
(3, 4, '2026.2', 10, 60, 'Aberta'),
(5, 5, '2026.2',  8, 70, 'Aberta');

-- ------------------------------------------------------------
-- matricula
-- media_final e situacao saem do trg_situacao_inicial; o que
-- vier no INSERT nessas colunas seria substituído, então nem
-- aparecem aqui. id_usuario 3 = sec.carla.
-- Colunas: aluno, turma, data, n1, n2, exame, faltas, usuario.
-- ------------------------------------------------------------

-- Turma 1 (Lógica, 2026.1): matrículas 1 a 8
INSERT INTO matricula (id_aluno, id_turma, data_matricula, n1, n2, exame, faltas, id_usuario) VALUES
(1, 1, '2026-02-02', 8.0, 9.0, NULL,  4, 3),
(2, 1, '2026-02-02', 7.5, 7.0, NULL,  8, 3),
(3, 1, '2026-02-02', 9.0, 8.5, NULL,  2, 3),
(4, 1, '2026-02-03', 6.0, 7.5, 6.0,  10, 3),
(5, 1, '2026-02-03', 7.0, 7.0, NULL,  6, 3),
(6, 1, '2026-02-03', 3.0, 2.5, NULL, 12, 3),
(7, 1, '2026-02-04', 5.0, 4.5, 3.0,   9, 3),
(8, 1, '2026-02-04', 8.0, 8.0, NULL, 30, 3);

-- Turma 2 (Algoritmos, 2026.1): matrículas 9 a 16
INSERT INTO matricula (id_aluno, id_turma, data_matricula, n1, n2, exame, faltas, id_usuario) VALUES
(10, 2, '2026-02-02', 9.0, 9.5, NULL,  3, 3),
(11, 2, '2026-02-02', 7.0, 8.0, NULL,  5, 3),
(12, 2, '2026-02-03', 8.5, 7.5, NULL,  6, 3),
(13, 2, '2026-02-03', 6.5, 7.5, NULL,  4, 3),
(14, 2, '2026-02-04', 7.5, 7.5, NULL, 10, 3),
(15, 2, '2026-02-04', 7.0, 6.0, 5.0,   7, 3),
(16, 2, '2026-02-05', 4.0, 5.0, 2.0,   8, 3),
(19, 2, '2026-02-05', 5.0, 5.5, NULL, 35, 3);

-- Turma 3 (POO, 2026.2, lotada): matrículas 17 a 20
INSERT INTO matricula (id_aluno, id_turma, data_matricula, n1, n2, exame, faltas, id_usuario) VALUES
(1, 3, '2026-08-03', 8.0,  NULL, NULL,  2, 3),
(2, 3, '2026-08-03', 6.0,  7.0,  NULL,  5, 3),
(3, 3, '2026-08-03', 9.5,  9.5,  NULL, 25, 3),
(4, 3, '2026-08-04', NULL, NULL, NULL,  0, 3);

-- Turma 4 (Banco de Dados, 2026.2): matrículas 21 a 29
INSERT INTO matricula (id_aluno, id_turma, data_matricula, n1, n2, exame, faltas, id_usuario) VALUES
(1, 4, '2026-08-03', 8.0,  7.0,  NULL, 1, 3),
(2, 4, '2026-08-03', NULL, NULL, NULL, 0, 3),
(3, 4, '2026-08-04', 9.0,  NULL, NULL, 0, 3),
(4, 4, '2026-08-04', 5.0,  6.0,  NULL, 3, 3),
(5, 4, '2026-08-04', 7.0,  8.0,  NULL, 3, 3),
(6, 4, '2026-08-05', NULL, NULL, NULL, 0, 3),
(7, 4, '2026-08-05', 4.0,  3.0,  NULL, 2, 3),
(8, 4, '2026-08-05', 6.0,  6.5,  5.5,  4, 3),
(9, 4, '2026-08-06', NULL, NULL, NULL, 0, 3);

-- Turma 5 (Estruturas de Dados, 2026.2): matrículas 30 a 35
INSERT INTO matricula (id_aluno, id_turma, data_matricula, n1, n2, exame, faltas, id_usuario) VALUES
(10, 5, '2026-08-03', 9.0,  9.0,  NULL, 1, 3),
(11, 5, '2026-08-03', 7.0,  NULL, NULL, 0, 3),
(12, 5, '2026-08-04', NULL, NULL, NULL, 0, 3),
(13, 5, '2026-08-04', 5.0,  5.5,  NULL, 2, 3),
(14, 5, '2026-08-05', 6.0,  6.0,  NULL, 3, 3),
(15, 5, '2026-08-05', NULL, NULL, NULL, 0, 3);

DELIMITER ;
-- <<< FIM DE 03_dados.sql


-- ============================================================
-- >>> INICIO DE 04_testes.sql
-- ============================================================

-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 04_testes.sql: roteiro de testes obrigatórios
-- Responsável: Mykael
-- ============================================================
-- Roda por último, depois do 03_dados.sql, e usa os IDs dos
-- cenários descritos no topo dele (banco recém-criado).
--
-- Como usar: rode o arquivo inteiro. Não precisa desligar o "parar no
-- erro" do Workbench: os testes que DEVEM falhar rodam por dentro da
-- sp_teste_erro, que captura o erro e só registra a mensagem. No final
-- sai uma tabela teste | esperado | obtido | resultado (OK ou
-- FALHOU). Essa tabela é a evidência para o relatório.
--
-- Não suja a massa de dados: os testes 1 a 10 e 12 rodam numa transação que
-- termina em ROLLBACK, e o teste 11 apaga o que criou. Só os contadores
-- de AUTO_INCREMENT avançam. As procedures auxiliares (sp_teste_*) são
-- apagadas no fim.
--
-- Testes obrigatórios do enunciado:
--    1 login com senha incorreta / usuário inexistente
--    2 matrícula em turma lotada
--    3 matrícula sem pré-requisito
--    4 matrícula de aluno Trancado (e Formado)
--    5 nota fora do intervalo
--    6 notas -> exame -> situação final
--    7 média 9,0 com frequência < 75%
--    8 alteração de notas gera log_nota
--    9 as 3 views
-- Extras do grupo:
--   10 Secretário tentando fechar o semestre
--   11 fechamento de semestre com sucesso e com ROLLBACK
--   12 matrícula em disciplina já aprovada e nota já lançada não se apaga
-- ============================================================

USE sga_fbi;

-- ------------------------------------------------------------
-- Preparação (fora da transação: CREATE PROCEDURE faz COMMIT)
-- A tabela de resultados é MEMORY (não transacional) para o ROLLBACK
-- dos testes não apagar o que já foi registrado nela.
-- ------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS teste_resultado;
CREATE TEMPORARY TABLE teste_resultado (
    ordem      INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    teste      VARCHAR(70)  NOT NULL,
    esperado   VARCHAR(150) NOT NULL,
    obtido     VARCHAR(255) NULL,
    resultado  VARCHAR(6)   NOT NULL
) ENGINE = MEMORY;

DROP PROCEDURE IF EXISTS sp_teste_erro;
DROP PROCEDURE IF EXISTS sp_teste_igual;

DELIMITER $$

-- Executa um comando que DEVE falhar e confere se a mensagem de erro
-- contém o trecho esperado.
CREATE PROCEDURE sp_teste_erro(
    IN p_teste     VARCHAR(70),
    IN p_comando   TEXT,
    IN p_esperado  VARCHAR(150)
)
BEGIN
    DECLARE v_msg TEXT DEFAULT NULL;

    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
    END;

    SET @sql_teste = p_comando;
    PREPARE stmt_teste FROM @sql_teste;
    EXECUTE stmt_teste;
    DEALLOCATE PREPARE stmt_teste;

    INSERT INTO teste_resultado (teste, esperado, obtido, resultado)
    VALUES (p_teste, p_esperado,
            COALESCE(v_msg, 'o comando NÃO falhou'),
            IF(v_msg LIKE CONCAT('%', p_esperado, '%'), 'OK', 'FALHOU'));
END$$

-- Compara dois valores como texto (NULL só é igual a NULL).
CREATE PROCEDURE sp_teste_igual(
    IN p_teste     VARCHAR(70),
    IN p_esperado  VARCHAR(150),
    IN p_obtido    VARCHAR(255)
)
BEGIN
    INSERT INTO teste_resultado (teste, esperado, obtido, resultado)
    VALUES (p_teste, COALESCE(p_esperado, 'NULL'), COALESCE(p_obtido, 'NULL'),
            IF(p_esperado <=> p_obtido, 'OK', 'FALHOU'));
END$$

DELIMITER ;

START TRANSACTION;

-- ============================================================
-- TESTE 1: login com senha incorreta / usuário inexistente
-- Esperado: 1ª e 2ª chamadas devolvem resultado VAZIO; a 3ª devolve
-- uma linha (id, nome, e-mail, perfil), sem a senha.
-- ============================================================
SELECT 'T1a: senha incorreta (esperado: vazio)' AS teste;
CALL sp_LoginUsuario('coord.ana', SHA2('senhaErrada', 256));

SELECT 'T1b: usuário inexistente (esperado: vazio)' AS teste;
CALL sp_LoginUsuario('ninguem', SHA2('Senha@123', 256));

SELECT 'T1c: senha correta (esperado: 1 linha, perfil Coordenador)' AS teste;
CALL sp_LoginUsuario('coord.ana', SHA2('Senha@123', 256));

-- ============================================================
-- TESTE 2: matrícula em turma lotada (RN05)
-- Turma 3 (POO): 4 vagas, 4 matriculados. Aluno 5 é Ativo e foi
-- aprovado em Lógica, então só a falta de vaga o barra.
-- ============================================================
CALL sp_teste_erro('T2: matrícula em turma lotada',
    'CALL sp_matricular_aluno(5, 3, 3)',
    'Turma lotada');

-- ============================================================
-- TESTE 3: matrícula sem pré-requisito (RN06)
-- Turma 5 (Estruturas de Dados) exige Algoritmos. O aluno 16 foi
-- 'Reprovado por Nota' em Algoritmos e a turma tem vagas.
-- ============================================================
CALL sp_teste_erro('T3: matrícula sem pré-requisito',
    'CALL sp_matricular_aluno(16, 5, 3)',
    'Falta pré-requisito');

-- ============================================================
-- TESTE 4: matrícula de aluno Trancado ou Formado (RN09)
-- ============================================================
CALL sp_teste_erro('T4a: matrícula de aluno Trancado',
    'CALL sp_matricular_aluno(19, 4, 3)',
    'Trancado');
CALL sp_teste_erro('T4b: matrícula de aluno Formado',
    'CALL sp_matricular_aluno(20, 4, 3)',
    'Formado');

-- ============================================================
-- TESTE 5: nota fora do intervalo 0 a 10 (RN07, CHECK)
-- ============================================================
CALL sp_teste_erro('T5a: N1 = 11,0 barrada pelo CHECK',
    'CALL sp_lancar_notas(20, 11.0, 5.0, 0, 1)',
    'ck_matricula_n1');
CALL sp_teste_erro('T5b: N2 = -1,0 barrada pelo CHECK',
    'CALL sp_lancar_notas(20, 5.0, -1.0, 0, 1)',
    'ck_matricula_n2');

-- ============================================================
-- TESTE 6: notas -> Em Exame -> exame -> situação final (RN02, RN03)
-- Matrícula 18 (aluno 2, turma 3): N1 6,0 e N2 7,0, parcial 6,5.
-- ============================================================
SELECT situacao INTO @situacao_antes FROM matricula WHERE id_matricula = 18;
CALL sp_teste_igual('T6a: N1 6,0 e N2 7,0 caem em', 'Em Exame', @situacao_antes);

CALL sp_teste_erro('T6b: exame de quem NÃO está Em Exame',
    'CALL sp_lancar_exame(17, 5.0, 1)',
    'Exame só pode ser lançado');

CALL sp_teste_erro('T6c: Secretário não lança exame',
    'CALL sp_lancar_exame(18, 5.0, 3)',
    'Apenas o Coordenador');

CALL sp_lancar_exame(18, 5.0, 1);
SELECT media_final, situacao INTO @media_exame, @situacao_exame
  FROM matricula WHERE id_matricula = 18;
CALL sp_teste_igual('T6d: média final com exame 5,0 = (6,5 + 5,0) / 2', '5.75', @media_exame);
CALL sp_teste_igual('T6e: situação final com média 5,75', 'Aprovado', @situacao_exame);

-- Exame reprovando: matrícula 24 (aluno 4, turma 4): 5,0 e 6,0, parcial 5,5.
SELECT situacao INTO @situacao_antes FROM matricula WHERE id_matricula = 24;
CALL sp_teste_igual('T6f: N1 5,0 e N2 6,0 caem em', 'Em Exame', @situacao_antes);
CALL sp_lancar_exame(24, 2.0, 1);
SELECT media_final, situacao INTO @media_exame, @situacao_exame
  FROM matricula WHERE id_matricula = 24;
CALL sp_teste_igual('T6g: média final com exame 2,0 = (5,5 + 2,0) / 2', '3.75', @media_exame);
CALL sp_teste_igual('T6h: situação final com média 3,75', 'Reprovado por Nota', @situacao_exame);

-- ============================================================
-- TESTE 7: média 9,0 com frequência < 75% (RN04)
-- Matrícula 17 (aluno 1, turma 3, 80 aulas): 25 faltas = 68,75% de
-- presença. Reprova por falta mesmo com média 9,0.
-- ============================================================
CALL sp_lancar_notas(17, 9.0, 9.0, 25, 1);
SELECT media_final, frequencia, situacao INTO @media_t7, @freq_t7, @situacao_t7
  FROM vw_boletim WHERE id_matricula = 17;
CALL sp_teste_igual('T7a: média final', '9.00', @media_t7);
CALL sp_teste_igual('T7b: frequência (%)', '68.75', @freq_t7);
CALL sp_teste_igual('T7c: situação com média 9,0 e 68,75% de presença', 'Reprovado por Falta', @situacao_t7);

SELECT situacao INTO @situacao_t7 FROM matricula WHERE id_matricula = 19;
CALL sp_teste_igual('T7d: cenário da massa (matrícula 19, 9,5 e 9,5)', 'Reprovado por Falta', @situacao_t7);

-- ============================================================
-- TESTE 8: alteração de notas gera registro em log_nota (RN08)
-- Matrícula 20 (aluno 4, turma 3) começa sem nenhuma nota. Lançar
-- N1 7,0 e N2 8,0 com 0 faltas deve gerar 2 linhas (n1 e n2); as
-- faltas não mudaram, então não geram linha.
-- ============================================================
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

SELECT 'T8: log_nota da matrícula 20' AS teste;
SELECT id_log, id_matricula, campo, valor_antigo, valor_novo, usuario, data_hora
  FROM log_nota WHERE id_matricula = 20 ORDER BY id_log;

-- ============================================================
-- TESTE 9: execução e consulta das 3 views
-- ============================================================
SELECT COUNT(*) INTO @n_boletim FROM vw_boletim;
SELECT COUNT(*) INTO @n_lotacao FROM vw_turmas_lotacao;
SELECT COUNT(*) INTO @n_desempenho FROM vw_desempenho_turma;
CALL sp_teste_igual('T9a: vw_boletim (1 linha por matrícula)', '35', @n_boletim);
CALL sp_teste_igual('T9b: vw_turmas_lotacao (1 linha por turma)', '5', @n_lotacao);
CALL sp_teste_igual('T9c: vw_desempenho_turma (1 linha por turma)', '5', @n_desempenho);

SELECT 'T9a: vw_boletim (aluno 1)' AS teste;
SELECT * FROM vw_boletim WHERE id_aluno = 1 ORDER BY semestre;
SELECT 'T9b: vw_turmas_lotacao' AS teste;
SELECT * FROM vw_turmas_lotacao ORDER BY id_turma;
SELECT 'T9c: vw_desempenho_turma' AS teste;
SELECT * FROM vw_desempenho_turma ORDER BY id_turma;

-- ============================================================
-- TESTE 10 (extra): Secretário tentando fechar o semestre
-- ============================================================
CALL sp_teste_erro('T10: Secretário fechando o semestre',
    'CALL sp_fechar_semestre(''2026.2'', 3)',
    'Apenas o Coordenador');

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

-- aluno 1: Aprovado em Lógica (matrícula 1) | aluno 6: Reprovado por Nota
SET @comando_repete_aprovado = CONCAT('CALL sp_matricular_aluno(1, ', @turma_repete, ', 3)');
CALL sp_teste_erro('T12a: repetir disciplina em que já foi Aprovado',
    @comando_repete_aprovado,
    'já foi aprovado');

CALL sp_matricular_aluno(6, @turma_repete, 3);
SELECT COUNT(*) INTO @n_repete_reprovado
  FROM matricula WHERE id_aluno = 6 AND id_turma = @turma_repete;
CALL sp_teste_igual('T12b: quem reprovou pode repetir a disciplina', '1', @n_repete_reprovado);

-- matrícula 17 (aluno 1, turma 3) já tem N1 = 8,0
CALL sp_teste_erro('T12c: apagar uma nota já lançada (N1 = NULL)',
    'CALL sp_lancar_notas(17, NULL, 9.0, 2, 1)',
    'apagar uma nota');

-- matrícula 22 (aluno 2, turma 4) ainda não tem nenhuma nota
CALL sp_lancar_notas(22, 7.0, NULL, 0, 1);
SELECT n1 INTO @n1_so_a_primeira FROM matricula WHERE id_matricula = 22;
CALL sp_teste_igual('T12d: lançar só a N1 onde ainda não há notas', '7.00', @n1_so_a_primeira);

-- Desfaz tudo o que os testes 1 a 12 alteraram.
ROLLBACK;

SELECT COUNT(*) INTO @log_depois FROM log_nota WHERE id_matricula = 20;
SELECT situacao INTO @situacao_depois FROM matricula WHERE id_matricula = 18;
CALL sp_teste_igual('ROLLBACK: log_nota da matrícula 20 voltou a vazio', '0', @log_depois);
CALL sp_teste_igual('ROLLBACK: matrícula 18 voltou a Em Exame', 'Em Exame', @situacao_depois);

-- ============================================================
-- TESTE 11 (extra): sp_fechar_semestre
-- Fora da transação acima: a procedure tem a própria transação.
-- Usa o semestre fictício 2099.1 (turma e matrículas criadas aqui e
-- apagadas no fim), para não encerrar o 2026.2 da massa de dados.
-- ============================================================
INSERT INTO turma (id_disciplina, id_professor, semestre, vagas, total_aulas, status)
VALUES (3, 4, '2099.1', 10, 60, 'Aberta');
SET @turma_fecha = LAST_INSERT_ID();

-- aluno 1: 8,0 e 7,0 (Aprovado) | aluno 2: 5,0 e 6,0 sem exame (Em Exame)
-- aluno 3: 9,0 e sem N2 (Cursando)
INSERT INTO matricula (id_aluno, id_turma, n1, n2, exame, faltas, id_usuario) VALUES
(1, @turma_fecha, 8.0, 7.0, NULL, 0, 3),
(2, @turma_fecha, 5.0, 6.0, NULL, 0, 3),
(3, @turma_fecha, 9.0, NULL, NULL, 0, 3);

CALL sp_teste_erro('T11a: fechar com matrícula sem N2 (Cursando)',
    'CALL sp_fechar_semestre(''2099.1'', 1)',
    'sem N1 ou N2');
SELECT status INTO @status_turma FROM turma WHERE id_turma = @turma_fecha;
SELECT situacao INTO @situacao_em_exame FROM matricula
 WHERE id_turma = @turma_fecha AND id_aluno = 2;
CALL sp_teste_igual('T11b: ROLLBACK, a turma continua', 'Aberta', @status_turma);
CALL sp_teste_igual('T11c: ROLLBACK, o Em Exame não foi alterado', 'Em Exame', @situacao_em_exame);

SELECT id_matricula INTO @matricula_sem_n2
  FROM matricula WHERE id_turma = @turma_fecha AND id_aluno = 3;
CALL sp_lancar_notas(@matricula_sem_n2, 9.0, 8.0, 0, 1);

SELECT 'T11: sp_fechar_semestre(2099.1) (esperado: Aprovado 2, Reprovado por Nota 1)' AS teste;
CALL sp_fechar_semestre('2099.1', 1);

SELECT status INTO @status_turma FROM turma WHERE id_turma = @turma_fecha;
SELECT situacao INTO @situacao_em_exame FROM matricula
 WHERE id_turma = @turma_fecha AND id_aluno = 2;
CALL sp_teste_igual('T11d: turma encerrada', 'Encerrada', @status_turma);
CALL sp_teste_igual('T11e: Em Exame sem exame virou', 'Reprovado por Nota', @situacao_em_exame);
SELECT CONCAT('CALL sp_lancar_notas(', id_matricula, ', 10.0, 10.0, 0, 1)')
  INTO @comando_nota_encerrada
  FROM matricula WHERE id_turma = @turma_fecha AND id_aluno = 1;
CALL sp_teste_erro('T11f: lançar nota em turma encerrada',
    @comando_nota_encerrada,
    'Turma encerrada');
CALL sp_teste_erro('T11g: fechar de novo o mesmo semestre',
    'CALL sp_fechar_semestre(''2099.1'', 1)',
    'Não há turma aberta');

-- Limpeza do teste 11
DELETE FROM log_nota
 WHERE id_matricula IN (SELECT id_matricula FROM matricula WHERE id_turma = @turma_fecha);
DELETE FROM matricula WHERE id_turma = @turma_fecha;
DELETE FROM turma WHERE id_turma = @turma_fecha;

-- ============================================================
-- RESULTADO: copie esta tabela para o relatório
-- ============================================================
SELECT teste, esperado, obtido, resultado FROM teste_resultado ORDER BY ordem;
SELECT SUM(resultado = 'OK') AS ok, SUM(resultado = 'FALHOU') AS falhou, COUNT(*) AS total
  FROM teste_resultado;

DROP TEMPORARY TABLE teste_resultado;
DROP PROCEDURE sp_teste_erro;
DROP PROCEDURE sp_teste_igual;

DELIMITER ;
-- <<< FIM DE 04_testes.sql
