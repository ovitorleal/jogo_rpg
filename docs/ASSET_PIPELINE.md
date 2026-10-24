# Pipeline de assets

## Arte atual (gerada por código)

Arte original desenhada por scripts, com saída determinística (`tools/art/`, fora da exportação):

```bash
# 1. Personagens animados (herói, goblin, lobo) e retrato
godot --headless --path . --script res://tools/art/generate_characters.gd
# 2. Atlas de terreno e objetos de cenário (árvores, arbustos, pedras, placa)
godot --headless --path . --script res://tools/art/generate_environment.gd
# 3. Importar
godot --headless --path . --import
# 4. TileSet, terreno e objetos do mapa de teste (não sobrescreve sem --force)
godot --headless --path . --script res://tools/art/build_overworld.gd -- --force
```

O passo 4 apaga edições manuais feitas no editor em `overworld_tileset.tres`, `test_map_terrain.tscn`
e `test_map_props.tscn`. Depois de editar o mapa no editor, não rode o passo 4 novamente.
`tools/art/pixel_canvas.gd` concentra as técnicas (partes com 3 tons, contorno seletivo, sombra).

## Fluxo para assets definitivos (especificação, seção 14)

1. Definir a necessidade e criar a especificação técnica (dimensões, quadros, pivô; ver `ART_BIBLE.md`).
2. Escrever o prompt a partir do modelo abaixo e registrá-lo no catálogo de prompts.
3. Gerar em ferramenta gratuita disponível; o Claude Code não gera imagens: só prepara prompts e processa arquivos.
4. Verificar consistência com a bíblia visual e com as referências aprovadas do personagem.
5. Reduzir, limpar e ajustar transparência e dimensões; montar spritesheets com ferramentas gratuitas.
6. Registrar origem e licença em `assets/asset_catalog.json` (`source_type`, `source_url`, `license`, `prompt_reference`).
7. Importar no Godot, integrar e verificar no jogo (desktop e Web).
8. Rodar os testes (o catálogo é validado automaticamente).

## Modelo de prompt

> Crie um asset original para um RPG 2D de fantasia medieval em pixel art. Categoria: [categoria]. Identidade visual: seguir a bíblia visual do projeto. Dimensões de saída: [dimensões]. Perspectiva: [perspectiva]. Paleta: [paleta]. Silhueta: [descrição]. Equipamentos: [descrição]. Iluminação: luz do alto à esquerda. Fundo: transparente quando aplicável. Não incluir texto, marca d'água, logotipo, interface ou elementos externos à área solicitada. Não imitar um personagem, arte, franquia ou artista específico. O resultado deve ser um asset original e legível na escala final do jogo.

Para spritesheets, acrescentar: número de linhas e colunas, dimensões exatas de cada quadro, ordem dos quadros,
direções, sequência de animação, espaçamento, fundo transparente e nenhum elemento atravessando os limites dos quadros.
Se o gerador não produzir uma folha correta, gerar quadros individuais e montá-los com ferramenta gratuita.

## Catálogo de prompts

| prompt_id | asset_id | Ferramenta | Prompt | Data |
|---|---|---|---|---|
| — | — | — | Nenhum asset gerado por IA ainda | — |
