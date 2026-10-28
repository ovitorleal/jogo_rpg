# Bíblia visual

## As Crônicas de Arghaz (a partir de 0.10.0) — direção atual

Ilustração em pixel art detalhado de alta resolução, com volume pintado, contorno escuro e muito detalhe de
tecido, couro e metal. As referências são as imagens do responsável: as folhas de classes e espécies, a vila e o logo.
Pode sair do pixel art estrito de 16 bits. Nada copiado de jogos existentes.

- **Personagens:** pose única de corpo inteiro, de frente e levemente de cima, fundo transparente. No jogo têm
  34 px de altura no mundo (`SpriteLibrary.FIGURE_HEIGHT`), com filtro suave e mipmaps. A animação é feita por
  código: balanço, avanço e espelho.
- **Mapas:** um fundo pintado por mapa, visto de cima, sem personagens. A área visível de 640×360 px do mundo
  corresponde a cerca de 1672×941 px de imagem.
- **Luz:** de cima à esquerda.
- **Interface** (`tools/art/build_ui_theme.gd`):

  | Cor | Valor | Uso |
  |---|---|---|
  | Azul-petróleo escuro | `#11161C` | fundos |
  | Dourado | `#D9A84D` | molduras |
  | Dourado claro | `#FFD780` | destaque |
  | Turquesa | `#58CFD9` | foco |
  | Texto claro | `#EFE8D5` | texto |

- **Arquivos:** originais em `art_source/arghaz/` e versões do jogo em `assets/characters/arghaz/`,
  `assets/backgrounds/` e `assets/ui/`.

O restante deste documento descreve a direção anterior (16 bits gerada por código), que vale para a arte ainda não
substituída.

**Estado:** direção 16 bits definida (2026-10-24). Assets atuais são originais, gerados por código
(`tools/art/`), com `approval_status: in_review` no catálogo até aprovação do desenvolvedor.
Ao mudar algo aqui, revisar os assets existentes e o catálogo (`assets/asset_catalog.json`).

## Direção artística

Pixel art de fantasia medieval no espírito dos RPGs e aventuras **16 bits**: cores saturadas e alegres,
contorno escuro seletivo, volume com sombreamento em 3 tons e animações expressivas.
A referência é a *categoria* de estilo (16 bits colorido), não um jogo específico: não copiar personagens,
cenários, paletas exatas ou composições de obras existentes (incluindo jogos citados como inspiração).

## Escala e resolução

| Item | Valor |
|---|---|
| Resolução interna | 640×360 (escala 2× para 1280×720) |
| Grade de tiles | 16×16 px |
| Quadro de personagem/criatura | Ocupa 32×32 px no mundo; pés na linha 29. Personagens e criaturas são desenhados em **alta resolução** (64×64, 2 pixels reais por pixel lógico) e exibidos com escala 0,5 (`SpriteLibrary.attach`) |
| Árvores | 32×48 px; pivô na base do tronco (linha 44) |
| Objetos pequenos | 16×16 px; pivô na linha 14–15 |
| Casa do combate | 32×32 px (2×2 tiles) |
| Retrato | 64×64 px (alta resolução), exibido em 64×64 |
| Colisão de personagem / objetos | Retângulo nos pés/base (10×6, 12×6) |

Personagens continuam com o tamanho de 32 px no mundo (2 tiles de altura); a alta resolução só aumenta o detalhe.
Cenário (tiles, árvores, objetos) segue em 1×.

## Personagens modulares

Personagens jogáveis são pintados por `scripts/presentation/character_painter.gd` a partir da aparência escolhida
(perfil da espécie em `data/appearance/`). Proporções: pernas 7 px e tronco 9 px no padrão; anões e pequeninos com
pernas de 5 px, golias com tronco de 10 px; cabeça de raio 6 (5,5 em gnomos e pequeninos). Peças novas entram em
`CharacterPainter.PARTS` (+ `NAMES` em português) e nos perfis das espécies que as usam.

## Técnica

- **Sombreamento** por parte do corpo/objeto, luz do alto à esquerda: bordas superiores/esquerdas clareiam,
  inferiores/direitas escurecem (`PixelCanvas.paint_part`). Em 1× são 3 tons; em alta resolução cada faixa ganha um
  tom intermediário (5 tons) e as rampas desviam o matiz (sombra para o violeta, luz para o amarelo quente).
- **Linhas internas** (alta resolução): onde uma parte encosta em outra já pintada (braço sobre o tronco, cabelo
  sobre o rosto) a borda recebe 1 pixel real escuro — separação nítida sem engrossar o contorno.
- **Formas arredondadas** (alta resolução): tronco, membros, capa e mechas usam retângulos de cantos redondos,
  elipses e polígonos (`mask_round_rect`, `mask_polygon`); olhos, boca e brilhos são desenhados pixel a pixel.
- **Contorno seletivo**: o contorno é uma versão bem escura da cor vizinha, misturada com `#1a1020`
  (`PixelCanvas.outline`); nunca preto puro. Em alta resolução tem 1 pixel real e é um pouco mais claro no lado iluminado.
- **Sombra no chão**: elipse roxo-escura com ~28% de opacidade sob personagens e objetos.
- **Terreno**: definido nos vértices da grade; cada tile escolhe a transição pelos 4 cantos (marching
  squares) com borda orgânica e realce na fronteira (grama clara, terra escura, espuma na água).
- **Água animada**: 3 quadros a 3 fps.
- **Texto**: nunca dentro de imagens; sempre controles de UI do Godot.
- **Filtro**: Nearest em todo o projeto; sem mipmaps em 2D.

## Paleta

| Uso | Rampa (escuro → claro) |
|---|---|
| Contorno base | `#1a1020` |
| Grama | `#3f7a34` `#4f9a3e` `#62b04a` `#7ccc5a` |
| Terra | `#7a5232` `#9c6c40` `#b88652` `#d2a46a` |
| Areia | `#b89a5c` `#d8bc7a` `#ecd496` `#fae8b4` |
| Água | `#1e4a8c` `#2a64b0` `#3c82d0` `#8cc8f2`, espuma `#e6f6ff` |
| Pedra | `#4a4a5c` `#6e6e84` `#9090a6` `#b8b8cc` |
| Folhagem | `#1e4a24` `#2f7a34` `#58b046` (pinheiro `#163a2a` `#245e3c` `#3e8a50`) |
| Herói: pele / cabelo | `#b8694a` `#f0ac84` `#ffd6b4` / `#4a2416` `#8a4424` `#c87442` |
| Herói: túnica / capa | `#22386e` `#3a66bc` `#6ea2f2` / `#6e1a28` `#b42e3c` `#ea5c5c` |
| Metal / ouro | `#5c6a84` `#b4c4da` `#f2f8ff` / `#86560e` `#d09c2c` `#ffe27a` |
| Goblin: pele | `#2e5a1c` `#62a034` `#a6dc5e` |
| Lobo: pelo | `#3e3e50` `#7e7e94` `#c4c4d6` |
| UI: fundo / texto / destaque | `#1a1423` / `#e6e1d3` / `#8597b8`, nomes `#e0b48a` |

## Animação

Folhas de 9 colunas × N linhas, quadros 64×64 em alta resolução ou 32×32 (`SpriteLibrary` deduz pela largura):

| Ação | Colunas | Quadros | FPS | Laço |
|---|---|---|---|---|
| Parado (respiração) | 0–1 | 2 | 2,5 | sim |
| Caminhada (pernas alternadas, braços opostos, corpo sobe 1 px) | 2–5 | 4 | 8 | sim |
| Ataque (preparação, golpe com rastro, recuperação) | 6–8 | 3 | 10 | não |

Humanoides: linhas baixo, esquerda, direita, cima. Quadrúpedes: esquerda, direita.
Esquerda é o espelho da direita. No combate, ataque = animação + investida de 7 px; dano = piscar em
vermelho + tremor + número subindo; queda = tombar e acinzentar (inimigo morto some).

## Nomes de arquivo

`assets/<categoria>/<nome>.png` em `snake_case`; folhas animadas com sufixo `_sheet`.
O `asset_id` segue `<categoria_singular>.<nome>` (ex.: `character.hero`).

## Restrições de conteúdo

Sem personagens, logotipos ou estilos de franquias, jogos comerciais ou artistas específicos. Ver `docs/ASSET_PIPELINE.md`.
