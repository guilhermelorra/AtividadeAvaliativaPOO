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
-- Não suja a massa de dados: os testes 1 a 10 rodam numa transação que
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

-- Desfaz tudo o que os testes 1 a 10 alteraram.
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
