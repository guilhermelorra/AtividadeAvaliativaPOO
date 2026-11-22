// ============================================================
// SGA - Sistema de Gestão Acadêmica
// gerar_slides.js: gera apresentacao/SGA_apresentacao.pptx
// Responsável: Diego
// ============================================================
// Modelo dos slides do grupo. A parte do Diego já está preenchida;
// as de Guilherme, Mykael e Leo têm um slide marcado "A PREENCHER"
// com os tópicos que o enunciado e o plano de ataque pedem.
//
// Dá para editar o .pptx direto no PowerPoint. Este script existe
// para refazer o modelo do zero se precisar:
//
//   cd apresentacao
//   npm install
//   node gerar_slides.js
//
// ATENÇÃO: gerar de novo sobrescreve o .pptx. Se alguém já editou os
// slides no PowerPoint, não rode sem combinar com o grupo.
// ============================================================

const path = require('path');
const pptxgen = require('pptxgenjs');

// Paleta (hex sem #)
const COR = {
  escuro: '0B3C49',   // fundo dos slides de abertura e divisória
  texto: '1F2A30',
  suave: '5B6B73',
  cartao: 'EEF4F5',
  destaque: 'F2A541', // âmbar
  branco: 'FFFFFF',
  claro: 'CFE3E8',
  codigo: '12303A',
};
const FONTE = 'Calibri';
const MONO = 'Courier New';

const pres = new pptxgen();
pres.layout = 'LAYOUT_16x9'; // 10" x 5.625"
pres.author = 'Grupo SGA';
pres.title = 'SGA - Sistema de Gestão Acadêmica';

// ---------- layouts ----------
pres.defineSlideMaster({
  title: 'CONTEUDO',
  background: { color: COR.branco },
  objects: [
    { text: { text: 'SGA · Sistema de Gestão Acadêmica · LBD',
              options: { x: 0.5, y: 5.2, w: 6, h: 0.3, fontFace: FONTE, fontSize: 10, color: COR.suave, margin: 0 } } },
  ],
  slideNumber: { x: 9.0, y: 5.2, w: 0.5, h: 0.3, fontFace: FONTE, fontSize: 10, color: COR.suave, align: 'right' },
});
pres.defineSlideMaster({ title: 'ESCURO', background: { color: COR.escuro } });

// ---------- helpers ----------
function titulo(slide, texto, dono) {
  slide.addText(texto, {
    x: 0.5, y: 0.3, w: 7.4, h: 0.7, fontFace: FONTE, fontSize: 28, bold: true,
    color: COR.escuro, margin: 0, valign: 'middle', isTextBox: true,
  });
  if (dono) etiqueta(slide, dono, 8.0, 0.47, 1.5);
}

// Etiqueta arredondada em fonte de código (o motivo visual do deck)
function etiqueta(slide, texto, x, y, w, escura) {
  slide.addText(texto, {
    shape: pres.ShapeType.roundRect, rectRadius: 0.08,
    x, y, w, h: 0.34, fontFace: MONO, fontSize: 11, bold: true, align: 'center', valign: 'middle',
    color: escura ? COR.escuro : COR.branco, fill: { color: escura ? COR.destaque : COR.escuro }, margin: 0,
  });
}

function cartao(slide, x, y, w, h, cor) {
  slide.addShape(pres.ShapeType.roundRect, {
    x, y, w, h, rectRadius: 0.08, fill: { color: cor || COR.cartao }, line: { color: cor || COR.cartao },
  });
}

function texto(slide, t, x, y, w, h, op) {
  slide.addText(t, Object.assign({
    x, y, w, h, fontFace: FONTE, fontSize: 14, color: COR.texto, margin: 0, valign: 'top', isTextBox: true,
  }, op || {}));
}

// Cartão com etiqueta de código, título e descrição
function cartaoObjeto(slide, x, y, w, h, nome, descricao, tag) {
  cartao(slide, x, y, w, h);
  texto(slide, nome, x + 0.2, y + 0.15, w - 0.4, 0.3, { fontFace: MONO, fontSize: 13, bold: true, color: COR.escuro });
  texto(slide, descricao, x + 0.2, y + 0.52, w - 0.4, h - 0.62, { fontSize: 12, color: COR.texto });
  if (tag) etiqueta(slide, tag, x + w - 1.15, y + 0.13, 0.95, true);
}

function divisoria(nome, branch, frase) {
  const s = pres.addSlide({ masterName: 'ESCURO' });
  etiqueta(s, 'branch: ' + branch, 0.5, 1.6, 2.2, true);
  s.addText(nome, { x: 0.5, y: 2.1, w: 9, h: 0.9, fontFace: FONTE, fontSize: 44, bold: true, color: COR.branco, margin: 0, isTextBox: true });
  s.addText(frase, { x: 0.5, y: 3.05, w: 9, h: 0.6, fontFace: FONTE, fontSize: 18, color: COR.claro, margin: 0, isTextBox: true });
  return s;
}

function aPreencher(nome, tituloSlide, topicos) {
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, tituloSlide, nome.toLowerCase());
  cartao(s, 0.5, 1.25, 9, 3.7);
  etiqueta(s, 'A PREENCHER', 0.75, 1.45, 1.6, true);
  texto(s, 'Slide reservado para ' + nome + '. Tópicos sugeridos pelo enunciado e pelo plano de ataque:',
    2.5, 1.45, 6.8, 0.5, { fontSize: 12, color: COR.suave });
  s.addText(topicos.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < topicos.length - 1 } })), {
    x: 0.75, y: 2.1, w: 8.5, h: 2.7, fontFace: FONTE, fontSize: 15, color: COR.texto,
    margin: 0, valign: 'top', paraSpaceAfter: 8, isTextBox: true,
  });
  s.addNotes('Modelo: substituir pelos slides de ' + nome + '.');
  return s;
}

// ============================================================
// 1. Abertura
// ============================================================
{
  const s = pres.addSlide({ masterName: 'ESCURO' });
  etiqueta(s, 'USE sga_fbi;', 0.5, 1.2, 1.8, true);
  s.addText('SGA', { x: 0.5, y: 1.7, w: 9, h: 1.1, fontFace: FONTE, fontSize: 72, bold: true, color: COR.branco, margin: 0, isTextBox: true });
  s.addText('Sistema de Gestão Acadêmica',
    { x: 0.5, y: 2.85, w: 9, h: 0.5, fontFace: FONTE, fontSize: 22, color: COR.claro, margin: 0, isTextBox: true });
  s.addText('Trabalho Prático Integrado · Laboratório de Banco de Dados · 23/11/2026',
    { x: 0.5, y: 3.45, w: 9, h: 0.4, fontFace: FONTE, fontSize: 14, color: COR.claro, margin: 0, isTextBox: true });
  s.addText('Guilherme · Diego · Mykael · Leo',
    { x: 0.5, y: 4.6, w: 9, h: 0.4, fontFace: FONTE, fontSize: 16, bold: true, color: COR.destaque, margin: 0, isTextBox: true });
}

// ============================================================
// 2. O sistema em uma página
// ============================================================
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'As regras ficam no banco, não na tela');
  const col = [
    ['Interface', 'Login, menu por perfil e telas. Só faz CALL em procedure e SELECT em view.'],
    ['Procedures', 'A porta de entrada: login com hash, matrícula, notas, exame e fechamento.'],
    ['Functions, views e triggers', 'Média, frequência, situação, vagas e auditoria, calculadas pelo banco.'],
    ['Tabelas', '9 tabelas na 3FN, com PK, FK, UNIQUE e CHECK garantindo os dados.'],
  ];
  col.forEach((c, i) => {
    const y = 1.25 + i * 0.95;
    cartao(s, 0.5, y, 9, 0.8, i === 2 ? COR.escuro : COR.cartao);
    texto(s, c[0], 0.75, y + 0.12, 2.9, 0.56, { fontSize: 16, bold: true, valign: 'middle', color: i === 2 ? COR.destaque : COR.escuro });
    texto(s, c[1], 3.75, y + 0.12, 5.5, 0.56, { fontSize: 13, valign: 'middle', color: i === 2 ? COR.branco : COR.texto });
  });
  s.addNotes('Visão em camadas. Cada camada confia na de baixo: a interface não calcula nada, o banco decide.');
}

// ============================================================
// 3. Divisão do trabalho
// ============================================================
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'Divisão do trabalho: uma branch por pessoa');
  const gente = [
    ['Guilherme', 'guilherme', 'Modelagem, DDL, massa de dados, cadastro de aluno e telas do Coordenador'],
    ['Diego', 'diego', 'Functions, views e triggers, script final e slides'],
    ['Mykael', 'mykael', 'As 6 stored procedures e o roteiro de testes'],
    ['Leo', 'leo', 'Base do app, login, menu por perfil e telas do Secretário'],
  ];
  gente.forEach((g, i) => {
    const x = 0.5 + i * 2.3;
    cartao(s, x, 1.25, 2.1, 2.75);
    texto(s, g[0], x + 0.2, 1.42, 1.7, 0.4, { fontSize: 18, bold: true, color: COR.escuro });
    etiqueta(s, g[1], x + 0.2, 1.9, 1.3);
    texto(s, g[2], x + 0.2, 2.4, 1.7, 1.5, { fontSize: 12 });
  });
  texto(s, 'A main só recebe código por Pull Request revisado por um colega: Diego revisa Guilherme, Mykael revisa Diego, Leo revisa Mykael e Guilherme revisa Leo.',
    0.5, 4.2, 9, 0.7, { fontSize: 13, color: COR.suave });
}

// ============================================================
// Guilherme (a preencher)
// ============================================================
divisoria('Guilherme', 'guilherme', 'Arquitetura do banco e telas do Coordenador');
const IMG = (...p) => path.join(__dirname, '..', 'relatorio', 'img', ...p);

// G1. Modelagem e DDL
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'Nove tabelas na 3FN', 'guilherme');
  s.addImage({ path: IMG('eer_sga_fbi.png'), x: 0.4, y: 1.15, w: 5.4, h: 5.4 / 1.513, sizing: { type: 'contain', w: 5.4, h: 3.57 } });
  const itens = [
    ['3FN', 'Dados de curso, disciplina e professor ficam nas próprias tabelas. Matrícula é a entidade do N:N aluno × turma.'],
    ['Constraints', 'PK, FK, UNIQUE e CHECK: notas de 0 a 10 (RN07) e textos com grafia exata (utf8mb4_bin).'],
    ['Derivados', 'media_final e situacao são recalculadas por trigger, então nunca divergem das notas.'],
    ['Massa', '20 alunos, 5 turmas e 35 matrículas, com um cenário para cada teste obrigatório.'],
  ];
  itens.forEach((it, i) => {
    const y = 1.2 + i * 0.93;
    cartao(s, 6.2, y, 3.35, 0.83);
    texto(s, it[0], 6.35, y + 0.07, 3.1, 0.25, { fontFace: MONO, fontSize: 11, bold: true, color: COR.escuro });
    texto(s, it[1], 6.35, y + 0.33, 3.1, 0.5, { fontSize: 10.5, color: COR.texto });
  });
  texto(s, 'Os dados rodam depois dos triggers: se a massa estiver errada, o banco recusa.',
    0.5, 4.78, 5.5, 0.3, { fontSize: 11, color: COR.suave });
  s.addNotes('Diagrama gerado a partir do modelo (relatorio/img/eer_sga_fbi.png). Justificativa completa da 3FN na seção 3 do relatório, com a única redundância deliberada: media_final e situacao.');
}

// G2. Telas do Coordenador
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'Telas do Coordenador', 'guilherme');
  const w = 4.4, h = w / 1.75;
  s.addImage({ path: IMG('telas', '36_coord_notas_apos_exame.png'), x: 0.5, y: 1.2, w, h, sizing: { type: 'contain', w, h } });
  s.addImage({ path: IMG('telas', '42_coord_rel_faturamento.png'), x: 5.1, y: 1.2, w, h, sizing: { type: 'contain', w, h } });
  texto(s, 'Notas e exame: o banco recalcula média e situação na hora', 0.5, 1.2 + h + 0.05, w, 0.3, { fontSize: 11, color: COR.suave });
  texto(s, 'Relatórios: desempenho, lotação e faturamento em reais', 5.1, 1.2 + h + 0.05, w, 0.3, { fontSize: 11, color: COR.suave });
  const pontos = [
    'Fechar semestre é tudo ou nada: se faltar uma nota, nada muda e a mensagem aponta o aluno.',
    'Só procedures e views: nenhum INSERT, UPDATE ou DELETE no Java.',
    'O Secretário não vê essas telas, e o banco recusa a chamada mesmo assim.',
  ];
  s.addText(pontos.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < pontos.length - 1 } })), {
    x: 0.5, y: 4.0, w: 9, h: 1.1, fontFace: FONTE, fontSize: 13, color: COR.texto, margin: 0, valign: 'top',
    paraSpaceAfter: 5, isTextBox: true,
  });
  s.addNotes('Prints reais da aplicação. Casos de teste das telas na seção 7 do relatório (I15 a I21).');
}

// ============================================================
// Diego
// ============================================================
divisoria('Diego', 'diego', 'Regras de negócio dentro do banco');

// 5. Visão geral
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'As RNs viraram objetos do banco', 'diego');
  const nums = [
    ['6', 'functions', '4 do enunciado (com o CR opcional) e 2 auxiliares'],
    ['4', 'views', '3 do enunciado e o faturamento por curso'],
    ['4', 'triggers', '3 do enunciado e 1 extra na inserção'],
  ];
  nums.forEach((n, i) => {
    const x = 0.5 + i * 3.1;
    cartao(s, x, 1.25, 2.8, 2.3);
    texto(s, n[0], x + 0.25, 1.35, 2.3, 0.95, { fontSize: 60, bold: true, color: COR.escuro, valign: 'middle' });
    texto(s, n[1], x + 0.25, 2.3, 2.3, 0.35, { fontFace: MONO, fontSize: 15, bold: true, color: COR.escuro });
    texto(s, n[2], x + 0.25, 2.7, 2.3, 0.75, { fontSize: 12, color: COR.suave });
  });
  texto(s, 'Quem lança nota só grava N1, N2, exame e faltas. Média, situação, controle de vagas e auditoria saem do banco, então valem para qualquer tela e qualquer procedure.',
    0.5, 3.85, 9, 0.9, { fontSize: 15 });
  s.addNotes('Arquivo: database/02a_functions_views_triggers.sql. Ordem dentro do arquivo: functions, views, triggers, porque as views e os triggers usam as functions.');
}

// 6. fn_situacao
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'Uma função decide a situação do aluno', 'diego');
  const cab = { bold: true, color: COR.branco, fill: { color: COR.escuro }, fontFace: FONTE, fontSize: 13 };
  const lin = (a, b, c) => [
    { text: a, options: { fontFace: FONTE, fontSize: 13, color: COR.texto } },
    { text: b, options: { fontFace: MONO, fontSize: 12, bold: true, color: COR.escuro } },
    { text: c, options: { fontFace: FONTE, fontSize: 13, color: COR.suave, align: 'center' } },
  ];
  s.addTable([
    [{ text: 'Nesta ordem, se...', options: cab }, { text: 'a situação é', options: cab }, { text: 'Regra', options: Object.assign({ align: 'center' }, cab) }],
    lin('Frequência menor que 75%', "'Reprovado por Falta'", 'RN04'),
    lin('Falta N1 ou N2', "'Cursando'", ''),
    lin('Média parcial de 7,00 ou mais', "'Aprovado'", 'RN02'),
    lin('Média parcial abaixo de 4,00', "'Reprovado por Nota'", 'RN02'),
    lin('De 4,00 a 6,99, sem exame', "'Em Exame'", 'RN02'),
    lin('(Parcial + exame) / 2 de 5,00 ou mais', "'Aprovado'", 'RN03'),
    lin('Senão', "'Reprovado por Nota'", 'RN03'),
  ], {
    x: 0.5, y: 1.2, w: 9, colW: [4.1, 3.6, 1.3], rowH: 0.36,
    border: { type: 'solid', color: 'D5E0E3', pt: 0.75 }, fill: { color: COR.branco }, valign: 'middle', margin: [0, 0.1, 0, 0.1],
  });
  texto(s, 'A falta vem primeiro: média 9,0 com 73,75% de presença é reprovação por falta. A média é arredondada antes da comparação, para a situação sempre bater com a nota do boletim.',
    0.5, 4.3, 9, 0.75, { fontSize: 13, color: COR.suave });
  s.addNotes('fn_calcular_media cobre RN01 e RN03. fn_frequencia = (total_aulas - faltas) / total_aulas x 100, truncada em 2 casas. fn_situacao combina tudo.');
}

// 7. Views
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'Quatro views alimentam as telas', 'diego');
  const v = [
    ['vw_boletim', 'Aluno, RA, disciplina, semestre, notas, média, faltas e situação. Leva os ids que a tela de notas precisa.', 'Boletim'],
    ['vw_turmas_lotacao', 'Vagas, matriculados, vagas restantes e % de ocupação de cada turma.', 'Turmas'],
    ['vw_desempenho_turma', 'Média da turma, maior e menor nota, % de aprovados e de reprovados.', 'Relatório'],
    ['vw_faturamento_curso', 'Alunos ativos x mensalidade de cada curso. Só o Coordenador acessa.', 'Extra'],
  ];
  v.forEach((c, i) => {
    const x = 0.5 + (i % 2) * 4.6;
    const y = 1.25 + Math.floor(i / 2) * 1.85;
    cartaoObjeto(s, x, y, 4.4, 1.65, c[0], c[1], c[2]);
  });
  s.addNotes('A interface só faz SELECT nas views, nunca nas tabelas. vw_faturamento_curso usa a coluna valor_mensalidade, que o grupo acrescentou ao curso.');
}

// 8. Triggers
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'Os triggers protegem a tabela matricula', 'diego');

  const faixa = (y, evento, itens) => {
    etiqueta(s, evento, 0.5, y + 0.38, 1.5);
    itens.forEach((it, i) => {
      const x = 2.3 + i * 3.65;
      cartao(s, x, y, 3.45, 1.1);
      texto(s, it[0], x + 0.18, y + 0.1, 3.1, 0.3, { fontFace: MONO, fontSize: 12, bold: true, color: COR.escuro });
      texto(s, it[1], x + 0.18, y + 0.42, 3.1, 0.62, { fontSize: 11.5 });
    });
  };
  faixa(1.3, 'INSERT', [
    ['trg_valida_vagas', 'BEFORE · RN05. Turma lotada cancela a matrícula com SQLSTATE 45000.'],
    ['trg_situacao_inicial', 'BEFORE · extra. Já grava média e situação de quem entra com nota.'],
  ]);
  faixa(2.65, 'UPDATE', [
    ['trg_atualiza_situacao', 'BEFORE · RN01 a RN04. Mudou nota ou falta, recalcula média e situação.'],
    ['trg_auditoria_nota', 'AFTER · RN08. Uma linha em log_nota por campo alterado, com o usuário.'],
  ]);
  texto(s, 'Por estarem na tabela, valem para a massa de dados, para as procedures e para qualquer UPDATE feito direto no Workbench.',
    0.5, 4.1, 9, 0.7, { fontSize: 14 });
  s.addNotes('trg_valida_vagas usa SELECT ... FOR UPDATE na turma para duas matrículas simultâneas não passarem juntas na última vaga.');
}

// 9. Dificuldades do Diego
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'Três armadilhas que o banco escondia', 'diego');
  const d = [
    ['O BEFORE UPDATE lê a linha antiga',
     'Chamar fn_situacao(id) no trigger devolvia a situação do lançamento anterior.',
     'A regra foi para uma função que recebe os valores; o trigger passa NEW.*'],
    ['NULL não é diferente de nada',
     'OLD.n1 <> NEW.n1 dá NULL quando a nota era nula, e o primeiro lançamento ficava sem auditoria.',
     'Comparar com o operador <=>, que trata NULL como valor.'],
    ['6,995 é exame ou aprovado?',
     'A média tem 3 casas, a coluna guarda 2: o boletim mostraria 7,00 com "Em Exame".',
     'Arredondar antes de comparar; a frequência é truncada.'],
  ];
  d.forEach((c, i) => {
    const x = 0.5 + i * 3.1;
    cartao(s, x, 1.25, 2.9, 3.7);
    texto(s, c[0], x + 0.2, 1.4, 2.5, 0.7, { fontSize: 15, bold: true, color: COR.escuro });
    texto(s, 'PROBLEMA', x + 0.2, 2.15, 2.5, 0.25, { fontSize: 10, bold: true, color: COR.suave, charSpacing: 2 });
    texto(s, c[1], x + 0.2, 2.4, 2.5, 1.0, { fontSize: 12 });
    texto(s, 'SOLUÇÃO', x + 0.2, 3.5, 2.5, 0.25, { fontSize: 10, bold: true, color: COR.suave, charSpacing: 2 });
    texto(s, c[2], x + 0.2, 3.75, 2.5, 1.05, { fontSize: 12, bold: true, color: COR.escuro });
  });
  s.addNotes('Detalhes em relatorio/functions_views_triggers.md, seção Dificuldades e soluções.');
}

// ============================================================
// Mykael e Leo (a preencher)
// ============================================================
// Tabela simples no estilo do deck
function tabelaSimples(slide, cabecalho, linhas, o) {
  const fs = o.fs || 11;
  const cab = { bold: true, color: COR.branco, fill: { color: COR.escuro }, fontFace: FONTE, fontSize: fs };
  const rows = [cabecalho.map((t, i) => ({ text: t, options: Object.assign({ align: o.centro && o.centro.includes(i) ? 'center' : 'left' }, cab) }))];
  linhas.forEach((l) => rows.push(l.map((t, i) => ({
    text: t,
    options: {
      fontFace: i === 0 && o.mono ? MONO : FONTE, fontSize: i === 0 && o.mono ? fs - 0.5 : fs,
      bold: i === 0, color: i === 0 ? COR.escuro : COR.texto,
      align: o.centro && o.centro.includes(i) ? 'center' : 'left',
    },
  }))));
  slide.addTable(rows, {
    x: o.x, y: o.y, w: o.w, colW: o.colW, rowH: o.rowH || 0.36,
    border: { type: 'solid', color: 'D5E0E3', pt: 0.75 }, fill: { color: COR.branco }, valign: 'middle', margin: [0, 0.1, 0, 0.1],
  });
}

function marcadores(slide, itens, x, y, w, h, fs) {
  slide.addText(itens.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < itens.length - 1 } })), {
    x, y, w, h, fontFace: FONTE, fontSize: fs || 13, color: COR.texto, margin: 0, valign: 'top',
    paraSpaceAfter: 5, isTextBox: true,
  });
}

// ============================================================
// Mykael
// ============================================================
divisoria('Mykael', 'mykael', 'Procedures e a prova de que tudo funciona');

// M1. As seis procedures
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'Seis procedures, uma porta de entrada', 'mykael');
  tabelaSimples(s, ['Procedure', 'O que faz', 'Regras'], [
    ['sp_LoginUsuario', 'Confere login e hash; devolve id, nome, e-mail e perfil. Nunca devolve a senha', 'Vazio se não conferir'],
    ['sp_matricular_aluno', 'Cria a matrícula depois de checar aluno ativo, turma aberta e pré-requisito', 'RN05, RN06, RN09'],
    ['sp_lancar_notas', 'Grava N1, N2 e faltas; o trigger calcula média e situação', 'RN07, RN08; só Coordenador'],
    ['sp_lancar_exame', 'Grava o exame, só se a matrícula está Em Exame', 'RN03; só Coordenador'],
    ['sp_historico_aluno', 'Todas as disciplinas do aluno, ordenadas por semestre', 'Aluno inexistente dá erro'],
    ['sp_fechar_semestre', 'Percorre as matrículas com um cursor, dentro de uma transação, e encerra as turmas', 'Tudo ou nada; só Coordenador'],
  ], { x: 0.5, y: 1.2, w: 9, colW: [2.2, 4.5, 2.3], rowH: 0.46, fs: 10.5, mono: true });
  texto(s, 'Regra quebrada vira SIGNAL SQLSTATE 45000 com uma mensagem legível. A tela só mostra essa mensagem.',
    0.5, 4.68, 9, 0.35, { fontSize: 12, color: COR.suave });
  s.addNotes('As procedures não calculam média nem situação: só gravam n1, n2, exame e faltas. O trigger trg_atualiza_situacao faz o resto, então a regra existe em um lugar só.');
}

// M2. Hash, perfis e testes
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'Hash de senha e 39 testes', 'mykael');
  cartao(s, 0.5, 1.2, 4.4, 3.75);
  texto(s, 'Senha e perfis', 0.7, 1.32, 4, 0.3, { fontFace: MONO, fontSize: 13, bold: true, color: COR.escuro });
  marcadores(s, [
    'SHA-256 em hexadecimal, guardado em CHAR(64)',
    'O app calcula o hash; o banco só compara',
    'A resposta não diz se errou o login ou a senha',
    'O perfil é conferido no banco: Secretário não lança nota nem fecha semestre, mesmo chamando a procedure direto',
  ], 0.7, 1.72, 4.0, 2.2, 12);
  texto(s, 'Dificuldade: testes que devem falhar paravam o script. A sp_teste_erro captura a mensagem e segue.',
    0.7, 4.0, 4.0, 0.85, { fontSize: 11, color: COR.suave });
  cartao(s, 5.1, 1.2, 4.4, 3.75);
  texto(s, '04_testes.sql', 5.3, 1.32, 4, 0.3, { fontFace: MONO, fontSize: 13, bold: true, color: COR.escuro });
  s.addText('39 de 39', { x: 5.3, y: 1.7, w: 4.0, h: 0.7, fontFace: FONTE, fontSize: 40, bold: true, color: '1F7A3E', margin: 0, isTextBox: true });
  texto(s, 'verificações OK, 0 falhas', 5.3, 2.4, 4.0, 0.3, { fontSize: 13, color: COR.suave });
  marcadores(s, [
    'Login errado devolve vazio',
    'Turma lotada, sem pré-requisito, aluno trancado ou formado',
    'Nota fora de 0 a 10 é recusada',
    'Em Exame, média 9 com muitas faltas, log de notas',
    'Secretário fechando semestre, aprovado repetindo disciplina e nota apagada são barrados',
  ], 5.3, 2.85, 4.0, 2.0, 11.5);
  s.addNotes('A tabela esperado x obtido sai na execução do 04_testes.sql. Está no relatório, seção 7.');
}

// ============================================================
// Leo
// ============================================================
divisoria('Leo', 'leo', 'A cara do sistema');

// L1. Arquitetura da interface
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'A interface não tem regra de negócio', 'leo');
  tabelaSimples(s, ['Classe', 'Papel'], [
    ['LoginFrame', 'Gera o hash e chama sp_LoginUsuario'],
    ['DashboardFrame', 'Menu lateral por perfil, consultas e matrícula'],
    ['AlunosFrame', 'Cadastrar, editar e excluir alunos'],
    ['SgaRepository', 'Única classe que fala com o banco'],
    ['DatabaseConfig', 'Conexão a partir de variáveis de ambiente'],
    ['PasswordHash', 'Calcula o SHA-256 da senha'],
  ], { x: 0.5, y: 1.2, w: 4.9, colW: [1.7, 3.2], rowH: 0.5, fs: 10.5, mono: true });
  cartao(s, 5.6, 1.2, 3.9, 3.75);
  texto(s, 'Regras de ouro', 5.8, 1.32, 3.5, 0.3, { fontFace: MONO, fontSize: 13, bold: true, color: COR.escuro });
  marcadores(s, [
    'Só CALL e SELECT em view; nenhum INSERT, UPDATE ou DELETE',
    'Valores sempre como parâmetros, nunca concatenados',
    'Lista de views permitidas',
    'A senha do MySQL fica em variável de ambiente, fora do Git',
    'Colunas lidas pelo nome, não pela posição',
  ], 5.8, 1.72, 3.5, 3.1, 12);
  s.addNotes('Java 17, Swing, JDBC e Maven. A aparência usa a biblioteca FlatLaf.');
}

// L2. Login e perfis
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'Login com hash e menu por perfil', 'leo');
  s.addImage({ path: IMG('telas', '01_login.png'), x: 0.5, y: 1.2, w: 2.5, h: 2.9, sizing: { type: 'contain', w: 2.5, h: 2.9 } });
  tabelaSimples(s, ['Função', 'Secretário', 'Coordenador'], [
    ['Turmas, boletim e histórico', 'sim', 'sim'],
    ['Alunos e matrícula', 'sim', 'sim'],
    ['Notas e exame', 'não', 'sim'],
    ['Fechar semestre', 'não', 'sim'],
    ['Relatórios e auditoria', 'não', 'sim'],
  ], { x: 3.3, y: 1.2, w: 6.2, colW: [3.2, 1.5, 1.5], rowH: 0.38, fs: 11.5, centro: [1, 2] });
  texto(s, 'Duas camadas: a tela esconde o que o perfil não pode usar, e o banco recusa a operação mesmo se alguém chamar a procedure direto.',
    3.3, 3.75, 6.2, 0.7, { fontSize: 13, color: COR.texto });
  texto(s, 'A senha digitada vira SHA-256 no app e só o hash segue para o banco.',
    0.5, 4.4, 9, 0.4, { fontSize: 12, color: COR.suave });
  s.addNotes('O login inválido mostra apenas "Login ou senha inválidos", sem dizer qual campo errou.');
}

// ============================================================
// Encerramento
// ============================================================
{
  const s = pres.addSlide({ masterName: 'CONTEUDO' });
  titulo(s, 'Roteiro da demonstração', 'grupo');
  tabelaSimples(s, ['#', 'Quem entra', 'O que mostrar'], [
    ['1', 'coord.ana, senha errada', 'Login recusado: "Login ou senha inválidos."'],
    ['2', 'sec.carla', 'Menu sem coordenação e painel sem faturamento'],
    ['3', 'sec.carla', 'Matricular Rafael Domingues em Estruturas de Dados: o banco recusa (pré-requisito)'],
    ['4', 'sec.carla', 'Matricular Queila Macedo em Banco de Dados: matrícula realizada'],
    ['5', 'coord.ana', 'Lançar notas do Daniel Pacheco e o exame do Bernardo Cavalcante'],
    ['6', 'coord.ana', 'Auditoria mostra as linhas geradas pelo trigger; fechar semestre'],
  ], { x: 0.5, y: 1.2, w: 9, colW: [0.5, 2.5, 6.0], rowH: 0.46, fs: 11.5, centro: [0] });
  texto(s, 'Todas as senhas de teste são Senha@123. O fechamento é recusado enquanto houver matrícula sem N1 ou N2.',
    0.5, 4.7, 9, 0.35, { fontSize: 11.5, color: COR.suave });
  s.addNotes('Banco recém-criado com o SGA_completo.sql. Quem faz cada passo é combinado no ensaio.');
}
{
  const s = pres.addSlide({ masterName: 'ESCURO' });
  etiqueta(s, 'CALL sp_demonstracao();', 0.5, 1.6, 3.0, true);
  s.addText('Demonstração', { x: 0.5, y: 2.1, w: 9, h: 0.9, fontFace: FONTE, fontSize: 44, bold: true, color: COR.branco, margin: 0, isTextBox: true });
  s.addText('Login com cada perfil, matrícula barrada pelo banco, lançamento de notas e auditoria.',
    { x: 0.5, y: 3.05, w: 9, h: 0.6, fontFace: FONTE, fontSize: 18, color: COR.claro, margin: 0, isTextBox: true });
}

pres.writeFile({ fileName: path.join(__dirname, 'SGA_apresentacao.pptx') })
  .then((f) => console.log('Gerado: ' + f));
