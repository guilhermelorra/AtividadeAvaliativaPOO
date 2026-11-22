"""Gera apresentacao/SGA_apresentacao.html, a apresentação interativa em um arquivo só.

Uso:
    python apresentacao/gerar_html.py

Junta o modelo (html/template.html), o diagrama das tabelas (desenhado aqui, com as
mesmas tabelas do relatório) e alguns prints da aplicação (embutidos em base64), para
o arquivo abrir em qualquer navegador, sem internet e sem pastas ao lado.
"""
import base64
import html
import io
import json
import os
import re

from PIL import Image

PASTA = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(PASTA)
TELAS = os.path.join(RAIZ, 'relatorio', 'img', 'telas')

# ---------------------------------------------------------------- modelo de dados
TABELAS = {
    'usuario': {
        'desc': 'Quem usa o sistema. Perfil Secretario ou Coordenador; a senha fica só como hash SHA-256.',
        'cols': [('id_usuario', 'PK', 'INT'), ('nome', '', 'VARCHAR'), ('cpf', 'UK', 'CHAR(11)'), ('email', 'UK', 'VARCHAR'),
                 ('login', 'UK', 'VARCHAR'), ('senha_hash', '', 'CHAR(64)'), ('perfil', '', 'VARCHAR')]},
    'curso': {
        'desc': 'Curso da faculdade, com turno e mensalidade (a base do relatório de faturamento).',
        'cols': [('id_curso', 'PK', 'INT'), ('nome', '', 'VARCHAR'), ('carga_horaria_total', '', 'INT'), ('turno', '', 'VARCHAR'),
                 ('valor_mensalidade', '', 'DECIMAL(10,2)')]},
    'professor': {
        'desc': 'Docente que leciona turmas.',
        'cols': [('id_professor', 'PK', 'INT'), ('nome', '', 'VARCHAR'), ('cpf', 'UK', 'CHAR(11)'), ('email', 'UK', 'VARCHAR'),
                 ('titulacao', '', 'VARCHAR'), ('data_admissao', '', 'DATE')]},
    'disciplina': {
        'desc': 'Disciplina da grade de um curso, oferecida em um período (semestre da grade).',
        'cols': [('id_disciplina', 'PK', 'INT'), ('id_curso', 'FK', 'INT'), ('nome', '', 'VARCHAR'), ('carga_horaria', '', 'INT'),
                 ('periodo', '', 'TINYINT')]},
    'pre_requisito': {
        'desc': 'Quais disciplinas exigem aprovação em outras. É um autorrelacionamento N:N de disciplina.',
        'cols': [('id_disciplina', 'PK FK', 'INT'), ('id_disciplina_requisito', 'PK FK', 'INT')]},
    'aluno': {
        'desc': 'Estudante vinculado a um curso. Status: Ativo, Trancado ou Formado.',
        'cols': [('id_aluno', 'PK', 'INT'), ('ra', 'UK', 'VARCHAR'), ('nome', '', 'VARCHAR'), ('cpf', 'UK', 'CHAR(11)'),
                 ('email', 'UK', 'VARCHAR'), ('data_nascimento', '', 'DATE'), ('id_curso', 'FK', 'INT'), ('status', '', 'VARCHAR')]},
    'turma': {
        'desc': 'Oferta de uma disciplina, por um professor, em um semestre, com vagas e total de aulas.',
        'cols': [('id_turma', 'PK', 'INT'), ('id_disciplina', 'FK', 'INT'), ('id_professor', 'FK', 'INT'), ('semestre', '', 'CHAR(6)'),
                 ('vagas', '', 'INT'), ('total_aulas', '', 'INT'), ('status', '', 'VARCHAR')]},
    'matricula': {
        'desc': 'O aluno em uma turma: notas, faltas, média final e situação (calculadas pelos triggers).',
        'cols': [('id_matricula', 'PK', 'INT'), ('id_aluno', 'FK', 'INT'), ('id_turma', 'FK', 'INT'), ('data_matricula', '', 'DATE'),
                 ('n1', '', 'DECIMAL(4,2)'), ('n2', '', 'DECIMAL(4,2)'), ('exame', '', 'DECIMAL(4,2)'), ('faltas', '', 'INT'),
                 ('media_final', '', 'DECIMAL(4,2)'), ('situacao', '', 'VARCHAR'), ('id_usuario', 'FK', 'INT')]},
    'log_nota': {
        'desc': 'Auditoria (RN08): cada alteração de nota ou falta vira uma linha, escrita por um trigger.',
        'cols': [('id_log', 'PK', 'INT'), ('id_matricula', 'FK', 'INT'), ('campo', '', 'VARCHAR'), ('valor_antigo', '', 'DECIMAL'),
                 ('valor_novo', '', 'DECIMAL'), ('usuario', 'FK', 'INT'), ('data_hora', '', 'DATETIME')]},
}

POS = {
    'aluno': (0, 0), 'curso': (1, 0), 'disciplina': (2, 0), 'pre_requisito': (3, 0),
    'matricula': (0, 1), 'turma': (2, 1), 'professor': (3, 1),
    'log_nota': (0, 2), 'usuario': (1, 2),
}
W, HEAD, ROW, GAPX, GAPY, PAD = 240, 34, 24, 125, 56, 30
ALT = {n: HEAD + ROW * len(t['cols']) + 8 for n, t in TABELAS.items()}
ALT_LINHA = [max(ALT[n] for n, p in POS.items() if p[1] == r) for r in range(3)]
Y_LINHA = [PAD + sum(ALT_LINHA[:r]) + GAPY * r for r in range(3)]
CAIXA = {n: (PAD + c * (W + GAPX), Y_LINHA[r], W, ALT[n]) for n, (c, r) in POS.items()}
VB_W = PAD * 2 + 4 * W + 3 * GAPX
VB_H = Y_LINHA[2] + ALT_LINHA[2] + PAD


def L(n, dy): x, y, w, h = CAIXA[n]; return (x, y + dy)
def R(n, dy): x, y, w, h = CAIXA[n]; return (x + w, y + dy)
def T(n): x, y, w, h = CAIXA[n]; return (x + w / 2, y)
def B(n): x, y, w, h = CAIXA[n]; return (x + w / 2, y + h)


ux, uy = T('usuario')
# (pai, filho, rótulo, pontos da linha, explicação)
RELACOES = [
    ('curso', 'aluno', 'possui', [L('curso', 70), R('aluno', 70)],
     'Um curso tem vários alunos. Cada aluno pertence a um único curso (aluno.id_curso aponta para curso).'),
    ('curso', 'disciplina', 'oferece', [R('curso', 70), L('disciplina', 70)],
     'Um curso oferece várias disciplinas (disciplina.id_curso aponta para curso).'),
    ('aluno', 'matricula', 'faz', [B('aluno'), T('matricula')],
     'Um aluno tem várias matrículas, uma por turma que cursa. Aluno × turma é N:N, e a tabela matricula resolve isso e ainda guarda as notas.'),
    ('turma', 'matricula', 'recebe', [L('turma', 60), R('matricula', 60)],
     'Uma turma recebe várias matrículas, até o limite de vagas (RN05, barrado por um trigger).'),
    ('matricula', 'log_nota', 'gera', [B('matricula'), T('log_nota')],
     'Cada alteração de nota ou falta gera linhas no log (RN08, escritas pelo trigger de auditoria).'),
    ('disciplina', 'turma', 'é oferecida em', [B('disciplina'), T('turma')],
     'Uma disciplina pode ser oferecida em várias turmas, em semestres diferentes.'),
    ('professor', 'turma', 'leciona', [L('professor', 60), R('turma', 60)],
     'Um professor leciona várias turmas (turma.id_professor aponta para professor).'),
    ('disciplina', 'pre_requisito', 'exige', [R('disciplina', 52), L('pre_requisito', 52)],
     'A tabela pre_requisito liga uma disciplina às que ela exige. Serve à regra RN06: só se matricula quem foi aprovado no pré-requisito.'),
    ('disciplina', 'pre_requisito', 'é requisito de', [R('disciplina', 82), L('pre_requisito', 82)],
     'A mesma tabela aponta também para a disciplina exigida. Por isso é um autorrelacionamento N:N de disciplina.'),
    ('usuario', 'matricula', 'registra', [(ux, uy), (ux, Y_LINHA[1] + 240), R('matricula', 240)],
     'Guarda quem fez a matrícula ou o último lançamento de notas daquela linha.'),
    ('usuario', 'log_nota', 'altera', [L('usuario', 60), R('log_nota', 60)],
     'Guarda quem alterou a nota, para a tela de Auditoria mostrar o autor.'),
]

# ordem do modo guiado (índices em RELACOES)
ORDEM_GUIADA = [0, 1, 2, 3, 5, 6, 7, 9, 4, 10]


def esc(t):
    return html.escape(str(t), quote=True)


def svg_diagrama():
    out = [f'<svg id="er" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {VB_W} {VB_H}" role="img" '
           f'aria-label="Diagrama das nove tabelas do banco">']
    for i, (a, b, rot, pts, _txt) in enumerate(RELACOES):
        d = 'M' + ' L'.join(f'{x:.0f},{y:.0f}' for x, y in pts)
        seg = max(range(len(pts) - 1), key=lambda k: abs(pts[k + 1][0] - pts[k][0]) + abs(pts[k + 1][1] - pts[k][1]))
        (ax, ay), (bx, by) = pts[seg], pts[seg + 1]
        mx, my = (ax + bx) / 2, (ay + by) / 2
        horizontal = abs(ay - by) < 1
        lx, ly, anc = (mx, my - 7, 'middle') if horizontal else (mx + 8, my + 4, 'start')

        def ponta(p, q, txt):
            (px, py), (qx, qy) = p, q
            if abs(px - qx) >= abs(py - qy):
                dx = 10 if qx > px else -10
                return px + dx, py - 6, ('start' if dx > 0 else 'end'), txt
            return px + 7, py + (16 if qy > py else -8), 'start', txt

        t1 = ponta(pts[0], pts[1], '1')
        t2 = ponta(pts[-1], pts[-2], 'N')
        out.append(f'<g class="rel" data-i="{i}" data-a="{a}" data-b="{b}">'
                   f'<path class="hit" d="{d}"/><path class="line" d="{d}"/>'
                   f'<text class="rlabel" x="{lx:.0f}" y="{ly:.0f}" text-anchor="{anc}">{esc(rot)}</text>'
                   f'<text class="card" x="{t1[0]:.0f}" y="{t1[1]:.0f}" text-anchor="{t1[2]}">{t1[3]}</text>'
                   f'<text class="card" x="{t2[0]:.0f}" y="{t2[1]:.0f}" text-anchor="{t2[2]}">{t2[3]}</text></g>')
    for nome, dados in TABELAS.items():
        x, y, w, h = CAIXA[nome]
        out.append(f'<g class="tbl" data-t="{nome}" tabindex="0">'
                   f'<rect class="frame" x="{x}" y="{y}" width="{w}" height="{h}" rx="8"/>'
                   f'<path class="head" d="M{x},{y + HEAD} L{x},{y + 8} Q{x},{y} {x + 8},{y} L{x + w - 8},{y} Q{x + w},{y} {x + w},{y + 8} L{x + w},{y + HEAD} Z"/>'
                   f'<text class="title" x="{x + 14}" y="{y + 22}">{nome}</text>')
        for i, (col, chave, tipo) in enumerate(dados['cols']):
            cy = y + HEAD + 4 + i * ROW
            if i % 2 == 1:
                out.append(f'<rect class="zebra" x="{x + 1}" y="{cy}" width="{w - 2}" height="{ROW}"/>')
            if chave:
                cls = 'pk' if 'PK' in chave else ('fk' if 'FK' in chave else 'uk')
                out.append(f'<text class="key {cls}" x="{x + 10}" y="{cy + 16}">{chave}</text>')
            fs = 12 if len(col) > 18 else 13
            out.append(f'<text class="col{" pkc" if "PK" in chave else ""}" x="{x + 48}" y="{cy + 16}" style="font-size:{fs}px">{col}</text>')
            out.append(f'<text class="tipo" x="{x + w - 10}" y="{cy + 16}" text-anchor="end">{esc(tipo)}</text>')
        out.append('</g>')
    out.append('</svg>')
    return '\n'.join(out)


def dados_json():
    return json.dumps({
        'caixas': {n: {'x': c[0], 'y': c[1], 'w': c[2], 'h': c[3]} for n, c in CAIXA.items()},
        'tabelas': {n: {'desc': t['desc'], 'cols': [{'n': c[0], 'k': c[1], 't': c[2]} for c in t['cols']]} for n, t in TABELAS.items()},
        'relacoes': [{'a': r[0], 'b': r[1], 'rot': r[2], 'txt': r[4]} for r in RELACOES],
        'guiada': ORDEM_GUIADA,
        'vb': [0, 0, VB_W, VB_H],
    }, ensure_ascii=False)


# ---------------------------------------------------------------- imagens
def imagem_b64(nome, largura=1100):
    caminho = os.path.join(TELAS, nome + '.png')
    im = Image.open(caminho).convert('RGB')
    if im.width > largura:
        im = im.resize((largura, round(im.height * largura / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, 'JPEG', quality=84, optimize=True)
    return 'data:image/jpeg;base64,' + base64.b64encode(buf.getvalue()).decode('ascii')


def main():
    with open(os.path.join(PASTA, 'html', 'template.html'), encoding='utf-8') as f:
        modelo = f.read()
    modelo = modelo.replace('{{ER_SVG}}', svg_diagrama()).replace('{{ER_DATA}}', dados_json())
    modelo = re.sub(r'\{\{IMG:([A-Za-z0-9_]+)\}\}', lambda m: imagem_b64(m.group(1)), modelo)
    saida = os.path.join(PASTA, 'SGA_apresentacao.html')
    with open(saida, 'w', encoding='utf-8') as f:
        f.write(modelo)
    print('Gerado:', saida, f'({os.path.getsize(saida) / 1024:.0f} KB)')


if __name__ == '__main__':
    main()
