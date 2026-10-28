# Pedidos de arte — As Crônicas de Arghaz

Lista do que falta para todo o jogo ficar no estilo da arte nova. Para cada item há um pedido pronto para colar no
ChatGPT. **Em toda conversa, anexe primeiro a folha das 12 classes e a imagem da vila**, para o estilo não variar.

Coloque os arquivos prontos em `art_source/arghaz/`, nas pastas indicadas, com exatamente o nome de arquivo pedido.
Depois é só me avisar: a ferramenta `tools/art/import_arghaz.gd` limpa, recorta e liga tudo ao jogo.

Regras para todos os personagens e monstros:
- PNG com **fundo transparente**, um por arquivo, corpo inteiro, sem sombra no chão, sem texto;
- vista de frente, levemente de cima (como as classes);
- luz vindo de cima à esquerda;
- nada copiado de personagens de jogos existentes.

## Prioridade 0 — espécie vestida para a classe (pasta `sprites/combinacoes/`)

O personagem aparece com a ilustração da **espécie**. Para ele usar o equipamento da classe, é preciso uma imagem
para cada combinação. O nome do arquivo é `<especie>_<classe>.png`, por exemplo `anao_paladino.png`. Sem a
combinação, o jogo mostra a espécie com a roupa simples.

- Espécies: `anao`, `draconato`, `elfo`, `gnomo`, `golias`, `halfling`, `humano`, `orc`, `tiefling`.
- Classes: `barbaro`, `bardo`, `bruxo`, `clerigo`, `druida`, `feiticeiro`, `guerreiro`, `ladino`, `mago`, `monge`,
  `paladino`, `patrulheiro`.

São 108 imagens. Dá para fazer uma espécie por conversa: anexe a imagem da espécie e a folha das 12 classes e peça
uma imagem por classe.

> Esta é a minha personagem [anexo da espécie]. Desenhe **exatamente a mesma pessoa** (mesmo rosto, cabelo, pele,
> proporções e altura) vestida e equipada como o [classe] da folha de classes que enviei: mesma armadura, roupa e
> arma. Mesmo estilo de pixel art, corpo inteiro, de frente, levemente de cima, PNG com fundo transparente, sem
> sombra, 1024×1024.

Comece pelas combinações dos companheiros, que já têm ilustração própria, e pelas mais jogadas, como `humano_guerreiro`
e `elfo_mago`.

## Prioridade 1 — aparecem na aventura principal

### Mapas (pasta `mapas/`)

Mande a captura de referência junto do pedido. É ela que mantém caminhos, lago, ruína, rio e árvores no lugar, para
as colisões do jogo continuarem valendo (foi assim que a vila deu certo).

| Arquivo | Referência | Tamanho |
|---|---|---|
| `mapas/clareira.png` | `referencias/clareira_referencia.png` | 2880×1632 |
| `mapas/bosque_do_riacho.png` | `referencias/bosque_do_riacho_referencia.png` | 2112×1248 |

> Redesenhe este mapa visto de cima no mesmo estilo de pixel art detalhado da imagem da vila que enviei. Mantenha
> **exatamente** o mesmo layout: caminhos, lago, rio, ruína de pedra, árvores, pedras e arbustos nas mesmas posições e
> com o mesmo tamanho. Sem personagens, sem animais, sem texto e sem interface. Mesma proporção da referência
> (2880×1632), imagem opaca.

No Bosque do Riacho, troque a última frase por: "Inclua um pequeno acampamento goblin em volta da fogueira (tenda de
couro rasgada, estacas, ossos), sem goblins."

### NPCs (pasta `sprites/npcs/`)

| Arquivo | Pedido |
|---|---|
| `ione.png` | Mulher humana idosa, chefe de uma vila do campo, cabelo grisalho preso em coque, rosto gentil e firme, vestido verde-musgo com avental e xale marrom, cajado simples de madeira. |
| `amara.png` | Guarda de estrada humana, uns 30 anos, pele morena, cabelo escuro curto, gibão de couro sobre cota de malha, lança e escudo redondo de madeira, capa verde curta. |
| `estalajadeiro.png` | Estalajadeiro humano gordinho e simpático, bigode, avental manchado, caneca de cerveja na mão. (Opcional: só se quiser alguém no balcão da estalagem.) |

Pedido base (troque a descrição):
> Mesmo estilo das ilustrações das classes que enviei: [descrição]. Corpo inteiro, de frente, levemente de cima, PNG
> com fundo transparente, sem sombra, 1024×1024.

### Inimigos (pasta `sprites/monstros/`)

| Arquivo | Pedido |
|---|---|
| `goblin.png` | Goblin guerreiro magro de pele verde-oliva, orelhas compridas, dentes tortos, armadura de couro remendada, cimitarra enferrujada e escudo de tábuas, postura agressiva. |
| `garra_rubra.png` | Chefe goblin maior e mais forte, garra de metal vermelha no lugar da mão esquerda, armadura com espinhos, capa vermelha rasgada, cicatrizes, sorriso cruel. |
| `lobo.png` | Lobo cinzento faminto, magro, de perfil virado para a direita, rosnando, pelos arrepiados. |

Mesmo pedido base dos NPCs. Para os animais, use "de perfil, virado para a direita" no lugar de "de frente".

### Combate e viagem (pasta `mapas/`)

| Arquivo | Pedido |
|---|---|
| `arena_floresta.png` | Chão de clareira na floresta visto de cima, grama com flores e trechos de terra, sem árvores no meio (só nas bordas), sem personagens, iluminação uniforme. 1536×1024, opaco. |
| `estrada.png` | Faixa horizontal de uma estrada de terra no campo, vista lateral levemente de cima, colinas e árvores ao fundo, céu claro. 2048×512, opaco. |

### Tela de título (pasta `mapas/`)

| Arquivo | Pedido |
|---|---|
| `titulo.png` | Paisagem épica de Arghaz ao entardecer: vale verde, rio azul brilhante, montanhas, um vulcão distante e um dragão voando bem longe. Espaço livre no centro-alto para o logo. 1920×1080, opaco. |

## Prioridade 2 — itens (pasta `itens/`)

Ícones quadrados 256×256, fundo transparente, objeto centralizado, mesmo estilo:
`armadura.png`, `escudo.png`, `arma.png` (espada), `pocao.png` (poção de cura vermelha), `racao.png` (pão, queijo e
cantil) e `moeda.png` (pilha de moedas de ouro).

## Prioridade 3 — feras da Forma Selvagem (pasta `sprites/monstros/`)

Só aparecem quando um druida usa a Forma Selvagem. Todas de perfil virado para a direita:
`rato.png`, `aranha.png`, `cavalo.png`, `falcao.png`, `urso_negro.png`, `crocodilo.png`, `cavalo_de_guerra.png`,
`macaco.png`, `urso_pardo.png`, `lobo_atroz.png` e `aranha_gigante.png`.

## O que já está pronto

As 12 classes (usadas como referência de equipamento), as 9 espécies do SRD (o Aasimar fica guardado; ele não é do SRD 5.2.1), o logo e a vila. A interface
(painéis, botões e cores) eu refaço por código, nas cores do logo.
