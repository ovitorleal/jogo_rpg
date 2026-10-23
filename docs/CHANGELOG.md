# Changelog

## [0.1.0] — 2026-10-23 — Fase 1

### Adicionado
- Mapa de teste (60×34 tiles 16×16) com colisões em muros, água, rochas e arbustos.
- Jogador (`Player`): movimento em 8 direções, colisão nos pés, câmera seguindo com limites do mapa.
- Componente `Interactable` e placa interativa com mensagem no HUD (`ExplorationHud`).
- Controlador de mapa `ExplorationMap`.
- Ações de input: `move_up/down/left/right` (WASD + setas) e `interact` (E, Espaço, Enter); nomes das camadas de física.
- Tileset provisório (8 tiles) e placa gerados por script; `build_test_map.gd` gera TileSet e terreno.
- `docs/ART_BIBLE.md` e `docs/ASSET_PIPELINE.md` provisórios.
- 11 testes novos (9 de exploração, 2 de configuração): total 18.

### Alterado
- "Novo jogo" agora abre o mapa de teste (antes mostrava aviso de não implementado).
- Versão 0.0.1 → 0.1.0.

## [0.0.1] — 2026-10-23 — Fase 0

### Adicionado
- Projeto Godot 4.7.2 (Compatibility Renderer, viewport 640×360, filtro Nearest para pixel art).
- Tela de título provisória com "Novo jogo" (aviso de não implementado), "Continuar" (desabilitado) e "Sair" (oculto na Web).
- Sprite provisório 32×32 gerado por script e ícone SVG provisório.
- Catálogo de assets (`assets/asset_catalog.json`).
- Executor de testes próprio e 7 testes de integração (configuração, cena de título, preset Web, catálogo).
- Preset de exportação Web sem threads.
- Documentação inicial: README, CLAUDE.md, ARCHITECTURE, ROADMAP, RULES_POLICY, CONTENT_LICENSES, THIRD_PARTY_NOTICES.
