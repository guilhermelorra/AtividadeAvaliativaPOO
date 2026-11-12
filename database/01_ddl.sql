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
