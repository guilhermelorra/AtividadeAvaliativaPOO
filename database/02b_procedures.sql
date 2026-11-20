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
-- Além do mínimo: turma precisa estar 'Aberta' e o aluno não pode já
-- estar matriculado na turma.
--
-- Uso:  CALL sp_matricular_aluno(9, 4, 3);
-- Erros (45000): aluno, turma ou usuário inexistente; aluno não
--   'Ativo'; turma encerrada; já matriculado; falta pré-requisito;
--   turma lotada.
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
-- log_nota pelo trg_auditoria_nota. n1 e n2 podem ser NULL (nota ainda
-- não lançada); notas fora de 0 a 10 são barradas pelo CHECK (RN07).
--
-- Uso:  CALL sp_lancar_notas(20, 7.0, 8.0, 3, 1);
-- Erros (45000): usuário não é Coordenador; matrícula inexistente;
--   turma encerrada; faltas em branco ou negativas.
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

    SELECT perfil INTO v_perfil FROM usuario WHERE id_usuario = p_id_usuario;
    IF v_perfil IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário não encontrado.';
    END IF;
    IF v_perfil COLLATE utf8mb4_bin <> 'Coordenador' THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Apenas o Coordenador pode lançar notas.';
    END IF;

    SELECT t.status
      INTO v_status_turma
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
