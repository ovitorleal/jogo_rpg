# Arquitetura

## Decisões técnicas (Fase 0)

| Decisão | Motivo |
|---|---|
| Godot 4.7.2-stable, GDScript tipado | Stack exigida; última estável em 2026-10-23 |
| Renderer Compatibility | Único renderer suportado na Web (WebGL 2) |
| Viewport 640×360, stretch `canvas_items`, aspect `keep` | Base para pixel art; escala para 1280×720 (2×) e mantém proporção 16:9 |
| Filtro de textura padrão Nearest + snap 2D por pixel | Evitar borrar pixel art |
| Build Web sem threads (`variant/thread_support=false`) | Dispensa cabeçalhos COOP/COEP, compatível com hospedagens gratuitas |
| Testes com executor próprio (`tests/run_tests.gd`) | Sem dependências; GUT/gdUnit4 (ambos MIT) continuam opção |
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

### Fase 2

| Decisão | Motivo |
|---|---|
| Regras como funções estáticas sem estado (`RulesEngine`, `D20Test`, `Ability`, `Skill`) | Testáveis isoladamente; reutilizáveis no futuro servidor autoritativo |
| Toda aleatoriedade passa por `DiceRoller` (semente ou valores roteirizados) | Testes determinísticos; reprodução de bugs |
| Conteúdo em JSON (`data/<tipo>/*.json`, `{schema_version, entries}`) validado por esquema declarativo | Separar dados de lógica; mensagens de erro com arquivo, índice, id e campo |
| `CharacterData` guarda só escolhas; `CharacterSheet` recalcula o resto | Save pequeno e sem valores derivados que possam divergir das regras |
| Ao carregar: `CharacterData.from_dict` (estrutura) + `CharacterFactory.validate` (regras e conteúdo) | Rejeitar saves adulterados ou incoerentes |
| Autoloads `Content` e `PartyManager` | Conteúdo carregado uma vez; personagem preservado entre cenas |
| JSON incluídos na exportação via `include_filter = "data/*.json"` | `all_resources` não empacota arquivos que não são recursos |
| Texto do jogador escapado antes de ir para BBCode | Nome com `[` não pode injetar formatação |

## Camadas

A especificação (seções 7 e 8) define: Apresentação, Sistemas de jogo, Motor de regras, Dados de conteúdo,
Persistência e Ferramentas. Estado atual:

**Motor de regras** (`scripts/rules/`)
- `Ability`, `Skill`: constantes, nomes em português, modificador.
- `DiceRoller`, `DiceExpression` (`NdM±K`, sem execução de código), `D20Test` (vantagem/desvantagem, CD).
- `RulesEngine`: proficiência, bônus de teste, passivos, CA, PV máximos, iniciativa, deslocamento, validação de geração de atributos.

**Dados de conteúdo** (`scripts/core/`, `data/`)
- `ContentSchema`: validador (tipos, obrigatórios, enums, limites, referências, dados, campos desconhecidos, duplicatas em listas).
- `ContentRegistry`: carrega `data/`, valida, indexa por id estável (`class.fighter`, `item.dagger`...), checa referências
  cruzadas e consistência (ex.: armadura inicial exige treinamento da classe). `load_from_dictionaries` para testes.
- Autoload `Content` (`scripts/core/content.gd`): instância global; erros vão para o console.

**Sistemas de jogo — personagens e grupo** (`scripts/characters/`, `scripts/party/`)
- `CharacterData`: estado persistente e serialização (`to_dict`/`from_dict`, `schema_version` 1).
- `CharacterFactory`: cria personagens de nível 1 e valida qualquer personagem contra regras e conteúdo.
- `CharacterSheet`: ficha derivada e rolagens de teste/resistência do personagem.
- Autoload `PartyManager`: grupo atual (só o líder no MVP).

**Sistemas de jogo — exploração** (`scripts/exploration/`)
- `Player` (`scenes/characters/player.tscn`): movimento, colisão, câmera filha, detecção do `Interactable` mais próximo.
- `Interactable` (Area2D): componente genérico com `prompt_text`, `message_text`, `enabled` e o sinal `interacted`.
- `ExplorationMap`: controlador de um mapa; trata `interact` e `character_sheet` (C/Esc), bloqueia o jogador
  enquanto há mensagem ou ficha aberta.

**Apresentação** (`scenes/`, `scripts/ui/`)
- Título (`title_screen`): Novo jogo, Continuar (desabilitado), Créditos (atribuições), Sair (só desktop).
- Criação de personagem (`character_creation`): formulário + prévia ao vivo; só coleta escolhas, a validação é do `CharacterFactory`.
- `CharacterSheetPanel`: formata uma `CharacterSheet` (marcas "(P)"/"(E)" em texto, não só cor).
- `ExplorationHud`: aviso, mensagem e ficha.

Fluxo: Título → Criação → `PartyManager.start_new_party()` → Mapa de teste → [C] Ficha.

Módulos ainda não criados: `ExplorationManager` (estado entre mapas), `CombatManager`, `EncounterDirector`, `TravelSystem`,
`InventorySystem`, `QuestManager`, `DialogueSystem`, `SaveManager`, `AssetRegistry`, `AudioManager`, `SettingsManager`.

## Testes

- Arquivos `tests/**/test_*.gd` estendendo `res://tests/base_test.gd`; métodos `test_*` são executados em instâncias novas.
- `tree` dá acesso à `SceneTree`; os autoloads estão disponíveis também no modo `--script`.
- O executor retorna código 1 se houver falha ou nenhum teste.
- Pastas: `rules/`, `content/`, `characters/`, `exploration/`, `integration/`.

## Assets

- Catálogo central: `assets/asset_catalog.json` (campos da seção 17 da especificação), validado por `tests/integration/test_asset_catalog.gd`.
- Placeholders gerados por script: ver `docs/ASSET_PIPELINE.md`.
