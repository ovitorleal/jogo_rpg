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

## Camadas

A especificação (seções 7 e 8) define: Apresentação, Sistemas de jogo, Motor de regras, Dados de conteúdo,
Persistência e Ferramentas. Na Fase 0 existe apenas a camada de apresentação:

- `scenes/menus/title_screen.tscn` + `scripts/ui/title_screen.gd`: tela de título provisória (cena principal).

Os módulos (`RulesEngine`, `CombatManager`, `SaveManager` etc.) serão criados nas fases correspondentes.
Diretórios são criados somente quando recebem conteúdo.

## Testes

- Arquivos `tests/**/test_*.gd` estendendo `res://tests/base_test.gd`; métodos `test_*` são executados em instâncias novas.
- `tree` dá acesso à `SceneTree` para testes que instanciam cenas.
- O executor retorna código 1 se houver falha ou nenhum teste.

## Assets

- Catálogo central: `assets/asset_catalog.json` (campos da seção 17 da especificação), validado por `tests/integration/test_asset_catalog.gd`.
- Placeholders gerados por script: `tools/placeholders/generate_placeholders.gd`.
