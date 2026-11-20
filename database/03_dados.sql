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
