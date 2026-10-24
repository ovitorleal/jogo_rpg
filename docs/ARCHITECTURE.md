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
| Tiles 16×16, personagens ocupando 32×32 no mundo (desenhados em 64×64 desde 0.5.2) | Ver `ART_BIBLE.md` |
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

### Fase 3

| Decisão | Motivo |
|---|---|
| `CombatManager` é `RefCounted` puro, sem nós; recebe comandos e devolve eventos | Testável sem cena; resultado independente de animação; base para servidor autoritativo |
| Comandos validados (turno, ação, alcance, movimento) com mensagem de erro | A interface nunca altera estado diretamente |
| IA dos inimigos determinística por prioridades | Previsível e reproduzível com semente |
| Cena de combate separada; `ExplorationManager` (autoload) guarda retorno, encontros resolvidos e resultado | Estado da exploração sobrevive às trocas de cena |
| Gatilho de encontro só emite sinal; o mapa inicia o combate com `call_deferred` | Não remover a cena dentro de um callback de física |
| Falas com retrato: `Interactable.speaker_name/speaker_portrait`; vazio = o personagem do jogador | Mesmo componente serve para placas e futuros NPCs |

### Reforma visual (pós-Fase 3)

| Decisão | Motivo |
|---|---|
| Arte gerada por código com biblioteca própria (`tools/art/`) | Custo zero, determinística, consistente com a bíblia visual; trocável por arte final depois |
| `SpriteLibrary` monta `SpriteFrames` a partir de folhas com layout fixo | Um único formato para herói, inimigos e marcadores; sem recursos `.tres` por personagem |
| Terreno por vértices (marching squares) em camadas `Ground` + `Walls` | Bordas suaves sem autotile manual; colisão da água por quadrante |
| Objetos de cenário como cenas (`scenes/world/props/`) dentro do nó `Objects` com y-sort | Personagem passa atrás das árvores; colisão só na base |
| Combate: `CombatToken` por combatente; a cena "toca" os eventos do `CombatManager` em sequência | Animação nunca decide resultado; com `animations_enabled = false` o combate é idêntico |

### Fase 4

| Decisão | Motivo |
|---|---|
| `TravelSystem` e `EncounterDirector` são `RefCounted` puros; viagem serializável (`to_dict`) | Estado sobrevive à troca de cena para o combate; pronto para o salvamento da Fase 6 |
| Sorteios da viagem usam roladores derivados de (semente, contador) | Mesma semente = mesma viagem; nada depende da ordem de cenas |
| Mapas, rotas, regiões e eventos em JSON validado (referências cruzadas, CD obrigatória em testes) | Conteúdo novo sem código |
| `Interactable.action` (`travel:<rota>`, `rest_long`) com confirmação no HUD; o mapa executa | Componente continua sem lógica; ações destrutivas/longas pedem confirmação |
| Entradas de mapa como `Marker2D` em `Entrances/` | Chegada de viagem posiciona o jogador sem coordenadas no código |
| `CharacterData` esquema 2 (`hit_dice_spent`) com `migrate()` | Primeira migração de dados salvos, testada |

### Fase 5

| Decisão | Motivo |
|---|---|
| `Inventory` do grupo (pilhas + ouro) separado do equipamento em `CharacterData` | Equipar move itens entre os dois; save simples |
| `QuestLog` e `DialogueRunner` puros e serializáveis; autoload `QuestManager` | Testáveis sem cena; prontos para o salvamento |
| Diálogos em dados com condições/ações declarativas (`quest_ready:<id>`, `start_quest:<id>`...) validadas no carregamento | Conteúdo narrativo sem código e sem referências quebradas |
| Objetivos avançam por notificações (`defeat_encounter`, `reach_map`); avisos de outras cenas ficam pendentes | Combate e viagem não conhecem missões |
| Executor de testes reprova scripts que não compilam e erros de script durante um teste (`Logger`) | Antes, um erro em tempo de execução podia passar como teste aprovado |
| Teste que carrega todos os scripts e cenas | Nenhum script quebrado passa sem ser carregado por algum teste |

### Aparência modular (0.5.1)

| Decisão | Motivo |
|---|---|
| Sprites de personagem pintados em tempo de execução (`CharacterPainter` + `PixelCanvas`), com cache por aparência + equipamento | Combinações demais para pré-renderizar; mesma técnica e paleta da arte gerada por `tools/art/` |
| Perfil por espécie em dados (`appearance`), validado contra `CharacterPainter.PARTS` | Opções de cada espécie sem código; nada de chifres em humano |
| `CharacterData.appearance` guarda só índices e nomes de peças; ausentes usam o padrão da espécie | Save pequeno e estável; migração v2→v3 trivial |
| Personagens em alta resolução (`PixelCanvas` com fator k = 2) exibidos com escala 0,5 via `SpriteLibrary.attach` | Mais detalhe e curvas suaves sem mudar tamanhos do mundo, colisões nem combate |
| Referência de arte do responsável fora do build (`docs/art_reference/.gdignore`) | Imagem gerada com IA serve de guia, não de asset |

### Fase 6

| Decisão | Motivo |
|---|---|
| `SaveGame` puro (sem arquivos) + autoload `SaveManager` (arquivos, autosave, indicador) | Formato e validação testáveis sem disco |
| Arquivo = `{format, checksum, body}` com `body` em texto e SHA-256 do texto | Detecta corte/alteração; números do JSON não voltam idênticos, o texto sim |
| Validação completa antes de gravar e antes de aplicar (`CharacterData.from_dict` + `CharacterFactory.validate`, inventário, missões, mapa, rota) | Nunca gravar nem carregar estado incoerente |
| Temporário conferido → cópia de recuperação → principal relido; leitura com fallback | Gravação interrompida não perde o progresso |
| Autosave por pedidos agrupados, gravado só quando a cena diz que está consistente (`save_blocker()`) | Sem gravar a cada quadro nem no meio de conversa/combate |
| Viagem com combate pendente não é salva | Ao carregar, a tela de viagem não teria como retomar o combate |
| Executor de testes usa `user://test_save` e desliga autosave/indicador | Testes nunca tocam no salvamento do jogador |

### Fase 6.5

| Decisão | Motivo |
|---|---|
| Regras de conjuração em `Spellcasting` (puro) e resolução das magias dentro do `CombatManager` | Regras fora da UI; estado de combate só muda via `submit()` |
| Magias em dados (`spell`): alvo, resolução (ataque, resistência, automático, cura, efeito), dados, efeito, concentração, estilo visual | Magias novas sem código, desde que usem resoluções e efeitos existentes |
| Efeitos como dicionários no `Combatant` com regra de expiração (`turn_start`, `turn_end`, `concentration`) | Duração "até o próximo turno" e concentração sem temporizadores |
| Efeitos visuais por estilo (`SpellVfx`), desenhados por código e aguardados pela cena | Sem assets novos; resultado já resolvido antes da animação |

### Fase 6.6 (entrega 1)

| Decisão | Motivo |
|---|---|
| Escolhas como dados genéricos (`CharacterChoices`: especificação -> `CharacterData.choices`) a partir do campo `grants` das características | Um formato para talentos, estilos, maestria, subclasse, invocações...; UI única (`ChoicesPanel`) na criação e na tecla L |
| Padrões automáticos para toda escolha nova (fill_defaults); validação só recusa valores inválidos | Subir de nível nunca trava; saves antigos migram sem perguntas |
| Recursos em dados (valores por nível + recarga) e `ClassFeatures` para máximo/gasto/descanso | Tabelas do SRD sem código; descansos tratam todas as classes |
| Características como dados completos (1–20) com `implemented`; comportamento ligado por id no motor | Ficha mostra tudo desde já, sem afirmar que algo funciona antes de funcionar |
| Movimento casa a casa no `CombatManager` | Ataques de oportunidade no ponto exato em que o inimigo sai do alcance |

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

**Sistemas de jogo — combate** (`scripts/combat/`)
- `Combatant`: participante montado de `CharacterData` (ataques derivados da ficha) ou de um monstro.
- `CombatManager`: posicionamento, iniciativa, turnos, comandos (`move`, `attack`, `end_turn`, `flee`), IA, fim e resultados.
- `CombatLog`: texto do registro a partir dos eventos (apresentação).
- `CombatBoard` + `combat_scene`: grade clicável sobre grama, ordem de iniciativa, registro, ações, painel de resultado.
- `CombatToken`: sprite animado + barra de PV; andar entre casas, investida de ataque, dano (piscar, tremor), queda.

**Apresentação compartilhada** (`scripts/presentation/`)
- `SpriteLibrary`: animações `idle/walk/attack_<direção>` a partir das folhas de sprites.

**Sistemas de jogo — viagem e encontros** (`scripts/travel/`, `scripts/encounters/`)
- `EncounterDirector`: filtra a tabela da região (dia/noite, únicos, último acontecimento, orçamento de XP) e sorteia por peso.
- `TravelSystem`: trechos, relógio, rações, eventos com escolhas e testes de perícia, combate pendente, descansos, chegada.
- `travel_scene` + `RouteStrip`: faixa ilustrada com o herói andando de marco em marco, painel de eventos, ações.
- `Rest` (`scripts/characters/`): Dados de Vida e descanso longo.

**Sistemas de jogo — progressão, inventário, missões e diálogo**
- `Progression` (`scripts/characters/`): XP, níveis, PV e características novas.
- `Inventory` (`scripts/inventory/`): pilhas, ouro, recompensas, equipar/desequipar, consumíveis, serialização.
- `QuestLog` + autoload `QuestManager` (`scripts/quests/`): estado das missões, objetivos, recompensas.
- `DialogueRunner` (`scripts/dialogue/`): nós, condições, escolhas e ações de diálogo.
- `Npc` (`scripts/exploration/npc.gd`): Interactable com sprite; ação `talk:<diálogo>`.
- UI: `InventoryPanel` (I), `JournalPanel` (J), escolhas de diálogo na caixa de fala do HUD.

**Sistemas de jogo — exploração** (`scripts/exploration/`)
- Autoload `ExplorationManager`: retorno ao mapa, gatilhos resolvidos/desarmados, último resultado.
- `EncounterTrigger` (Area2D): inicia um encontro (`data/encounters/`); some após vitória; após fuga, só rearma ao sair da área.
- `Player` (`scenes/characters/player.tscn`): movimento, colisão, câmera filha, detecção do `Interactable` mais próximo.
- `Interactable` (Area2D): componente genérico com `prompt_text`, `message_text`, `enabled` e o sinal `interacted`.
- `ExplorationMap`: controlador de um mapa; trata `interact` e `character_sheet` (C/Esc), bloqueia o jogador
  enquanto há mensagem ou ficha aberta.

**Apresentação** (`scenes/`, `scripts/ui/`)
- Título (`title_screen`): Novo jogo, Continuar (desabilitado), Créditos (atribuições), Sair (só desktop).
- Criação de personagem (`character_creation`): formulário + prévia ao vivo; só coleta escolhas, a validação é do `CharacterFactory`.
- `CharacterSheetPanel`: formata uma `CharacterSheet` (marcas "(P)"/"(E)" em texto, não só cor).
- `ExplorationHud`: aviso, mensagem e ficha.

Fluxo: Título → Criação → `PartyManager.start_new_party()` → Mapa de teste → [C] Ficha / [E] falas com retrato →
área de encontro → Combate → vitória/fuga: volta ao mapa na mesma posição (PV e XP mantidos) · derrota: título.
Placa de estrada → (confirmar) → Viagem → trecho: nada / evento / combate (→ Combate → volta à Viagem) → chegada →
outro mapa na entrada da rota.

Módulos ainda não criados:
`InventorySystem`, `QuestManager`, `DialogueSystem`, `SaveManager`, `AssetRegistry`, `AudioManager`, `SettingsManager`.

## Testes

- Arquivos `tests/**/test_*.gd` estendendo `res://tests/base_test.gd`; métodos `test_*` são executados em instâncias novas.
- `tree` dá acesso à `SceneTree`; os autoloads estão disponíveis também no modo `--script`.
- O executor retorna código 1 se houver falha ou nenhum teste.
- Pastas: `rules/`, `content/`, `characters/`, `exploration/`, `integration/`.

## Assets

- Catálogo central: `assets/asset_catalog.json` (campos da seção 17 da especificação), validado por `tests/integration/test_asset_catalog.gd`.
- Placeholders gerados por script: ver `docs/ASSET_PIPELINE.md`.
