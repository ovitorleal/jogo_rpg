# Arquitetura

## Decisões técnicas (Fase 0)

| Decisão | Motivo |
|---|---|
| Godot 4.7.2-stable, GDScript tipado | Stack exigida; última estável em 2026-10-23 |
| Renderer Compatibility | Único renderer suportado na Web (WebGL 2) |
| Viewport 640×360, stretch `canvas_items`, aspect `keep` | Base para pixel art; escala para 1280×720 (2×) e mantém proporção 16:9 |
| Filtro de textura padrão Nearest + snap 2D por pixel | Evitar borrar pixel art |
| Build Web sem threads (`variant/thread_support=false`) | Dispensa cabeçalhos COOP/COEP, compatível com hospedagens gratuitas |
| Testes com executor próprio (`tests/run_tests.gd`) | Sem dependências na Fase 0; GUT/gdUnit4 (ambos MIT) podem ser avaliados na Fase 2 |
| `tests/` e `tools/` excluídos da exportação | Não distribuir código de desenvolvimento |
| Raiz do repositório = raiz do projeto Godot | Simplicidade; a pasta `fantasy-rpg/` da especificação corresponde a esta raiz |

### Fase 1

| Decisão | Motivo |
|---|---|
| Tiles 16×16, personagens em quadros 32×32 | Escala provisória; ver `ART_BIBLE.md` |
| `CharacterBody2D` em modo *floating*, 8 direções, 80 px/s, vetor normalizado | Top-down sem gravidade; diagonal não é mais rápida |
| Colisões só nos pés (retângulo 10×6) | Permite passar "atrás" de objetos com y-sort |
| Camadas de física: 1 `world`, 2 `player`, 3 `interactable` | Detector de interação só enxerga objetos interativos |
| Interação acionada pelo mapa, não pelo jogador | Um único ponto decide entre abrir/fechar mensagem; sem disputa de input no mesmo quadro |
| TileSet e terreno gerados por script uma vez, depois editáveis no editor | Reprodutível agora, fluxo nativo do Godot depois |

## Camadas

A especificação (seções 7 e 8) define: Apresentação, Sistemas de jogo, Motor de regras, Dados de conteúdo,
Persistência e Ferramentas. Estado atual:

**Apresentação**
- `scenes/menus/title_screen.tscn` + `scripts/ui/title_screen.gd`: tela de título (cena principal); "Novo jogo" abre o mapa de teste.
- `scenes/ui/exploration_hud.tscn` + `scripts/ui/exploration_hud.gd` (`ExplorationHud`): aviso de interação e caixa de mensagem. Só exibe.

**Sistemas de jogo — exploração** (`scripts/exploration/`)
- `Player` (`scenes/characters/player.tscn`): movimento, colisão, câmera filha, detecção do `Interactable` mais próximo.
  Expõe `input_enabled`, `try_interact()` e o sinal `interaction_target_changed`.
- `Interactable` (Area2D): componente genérico com `prompt_text`, `message_text`, `enabled` e o sinal `interacted`.
  Não decide o que acontece. Exemplo: `scenes/world/sign.tscn`.
- `ExplorationMap`: controlador de um mapa. Espera os nós únicos `%Ground`, `%Player` e `%Hud`; define os limites da câmera
  a partir dos tiles usados, liga os `Interactable` do mapa ao HUD e trata a ação `interact` (`handle_interact()`).

Fluxo de interação: `interact` (E/Espaço/Enter) → `ExplorationMap.handle_interact()` → fecha a mensagem aberta **ou**
`Player.try_interact()` → `Interactable.interacted` → `ExplorationMap` bloqueia o jogador e mostra a mensagem no HUD.

**Mapa de teste** (`scenes/world/test_map.tscn`): terreno `test_map_ground.tscn` (60×34 tiles), `Objects` com y-sort
(placa e jogador) e HUD.

Os demais módulos (`ExplorationManager` para estado entre mapas, `RulesEngine`, `CombatManager`, `SaveManager` etc.) serão
criados nas fases correspondentes. Diretórios são criados somente quando recebem conteúdo.

## Testes

- Arquivos `tests/**/test_*.gd` estendendo `res://tests/base_test.gd`; métodos `test_*` são executados em instâncias novas.
- `tree` dá acesso à `SceneTree` para testes que instanciam cenas.
- O executor retorna código 1 se houver falha ou nenhum teste.

## Assets

- Catálogo central: `assets/asset_catalog.json` (campos da seção 17 da especificação), validado por `tests/integration/test_asset_catalog.gd`.
- Placeholders gerados por script: ver `docs/ASSET_PIPELINE.md`.
