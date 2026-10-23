# Bíblia visual

**Estado:** provisória (Fase 1). Todos os valores podem mudar após os primeiros sprites de referência aprovados.
Ao mudar algo aqui, revisar os assets existentes e o catálogo (`assets/asset_catalog.json`).

## Direção artística

Pixel art de fantasia medieval, leitura clara em baixa resolução, silhuetas distintas, sem mistura com ilustração realista.
Um único estilo para todas as regiões, salvo justificativa documentada aqui.

## Escala e resolução

| Item | Valor |
|---|---|
| Resolução interna | 640×360 (escala 2× para 1280×720) |
| Grade de tiles | 16×16 px |
| Quadro de personagem | 32×32 px; figura de ~14×24 px, pés na linha 26–27 |
| Pivô | Nos pés (origem do nó no chão), para y-sort correto |
| Colisão de personagem | Retângulo 10×6 nos pés |
| Objetos de cenário pequenos | 16×16, base na última linha |

**Decisão pendente:** manter 32×32 ou migrar para 48×48 nos personagens.

## Paleta provisória

| Uso | Cores (hex) |
|---|---|
| Contorno / fundo de UI | `#1a1423` |
| Texto claro de UI | `#e6e1d3` |
| Destaque frio de UI | `#8597b8` |
| Grama | `#4a7a3a` `#3f6b32` `#5a8c45` |
| Terra/caminho | `#9c7b52` `#8a6a45` `#b08e62` |
| Areia | `#d8c48a` `#c8b47a` `#e4d29e` |
| Água | `#3a6ea5` `#305e92` `#5a8cc0` |
| Pedra | `#6b6b78` `#4a4a55` `#85859a` |
| Folhagem escura | `#2f5a2a` `#1f3a1c` |
| Madeira | `#9c7b52` `#6b4a2e` `#3d2b1f` |
| Pele / cabelo / armadura / capa (herói) | `#e0b48a` `#6b3e26` `#5a6b8c` `#8c2f39` |

Paletas por região: a definir quando a segunda região existir.

## Regras gerais

- **Contorno:** escuro (`#1a1423`) em personagens e objetos; tiles de terreno sem contorno.
- **Iluminação:** luz vindo do alto à esquerda; realce no topo-esquerda, sombra embaixo-direita.
- **Sombras:** elipse/linha preta com 30% de opacidade sob personagens e objetos.
- **Perspectiva:** top-down com leve projeção frontal (vemos frente e topo).
- **Transparência:** PNG RGBA; fundo 100% transparente; sem semitransparência fora de sombras e efeitos.
- **Texto:** nunca dentro de imagens; sempre controles de UI do Godot.
- **Filtro:** Nearest em todo o projeto; sem mipmaps em 2D.

## Animação (a definir na produção dos sprites definitivos)

Convenção prevista: 4 direções (baixo, cima, esquerda, direita); idle 2 quadros a 4 fps; walk 4 quadros a 8 fps.
Hoje o herói tem um único quadro, espelhado horizontalmente conforme a direção.

## Nomes de arquivo

`assets/<categoria>/<nome>.png` em `snake_case`; provisórios com prefixo `placeholder_`.
O `asset_id` segue `<categoria_singular>.<nome>` (ex.: `character.placeholder_hero`).

## Restrições de conteúdo

Sem personagens, logotipos ou estilos de franquias, jogos comerciais ou artistas específicos. Ver `docs/ASSET_PIPELINE.md`.
