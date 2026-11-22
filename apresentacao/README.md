# Apresentação

Slides para a apresentação oral de **23/11/2026**. Responsável por montar o modelo e juntar as partes: Diego.

Devem enfatizar:

- Divisão do trabalho entre os integrantes
- Dificuldades técnicas superadas

## Arquivos

| Arquivo | O que é |
|---------|---------|
| `SGA_apresentacao.pptx` | Os slides. É este que se edita e se apresenta. |
| `gerar_slides.js` | Script que gerou o modelo (Node.js + pptxgenjs). |
| `package.json` | Dependência do script. |

## Roteiro do modelo

| # | Slide | Quem |
|---|-------|------|
| 1 | Abertura | grupo |
| 2 | As regras ficam no banco, não na tela | grupo |
| 3 | Divisão do trabalho | grupo |
| 4–5 | Modelagem, DDL e telas do Coordenador | Guilherme — **a preencher** |
| 6–11 | Functions, views, triggers e dificuldades | Diego — pronto |
| 12–13 | Procedures, hash de senha e testes | Mykael — **a preencher** |
| 14–15 | Interface, login e controle de acesso | Leo — **a preencher** |
| 16 | Demonstração | grupo |

## Como cada um coloca a sua parte

1. Abra o `SGA_apresentacao.pptx` no PowerPoint.
2. Ache o slide com a etiqueta **A PREENCHER** e o seu nome. Ele lista os tópicos que o enunciado pede.
3. Troque o conteúdo pelos seus slides (pode duplicar o slide quantas vezes precisar) e apague a etiqueta.
4. Combine no grupo antes de editar: `.pptx` é binário, então duas pessoas editando ao mesmo tempo dá conflito que o Git não resolve. Edite um de cada vez ou mande os seus slides para o Diego juntar.

## Gerar o modelo de novo (opcional)

```bash
cd apresentacao
npm install
node gerar_slides.js
```

**Atenção:** isso sobrescreve o `SGA_apresentacao.pptx`. Só rode se ninguém tiver editado os slides no PowerPoint, ou o trabalho se perde.

## Versão interativa (HTML)

`SGA_apresentacao.html` é a mesma apresentação em um arquivo só, para abrir em qualquer navegador (sem internet). Tem diagrama das tabelas com zoom e explicação de cada relação, simulador da situação do aluno, fluxo dos triggers e troca de perfil. Atalhos: setas para navegar, `F` tela cheia, `G` lista de slides, `Esc` sai do modo guiado.

Para regenerar depois de mudar o conteúdo: edite `html/template.html` e rode `python apresentacao/gerar_html.py` (precisa do Python com a biblioteca Pillow). O diagrama é desenhado por esse script a partir do modelo de dados, e os prints vêm de `relatorio/img/telas`.
