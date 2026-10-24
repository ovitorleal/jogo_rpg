# Changelog

## [0.4.0] — 2026-10-24 — Fase 4

### Adicionado
- Conteúdo: tipos `map`, `region`, `route`, `event` validados; Floresta Sussurrante, Estrada do Leste (ida e volta),
  5 eventos (descoberta, NPC, perigo) e 2 encontros novos (dois lobos à noite, batedor goblin de dia).
- `EncounterDirector`, `TravelSystem` (serializável, reproduzível com semente) e tela de viagem com `RouteStrip`.
- `Rest` (descanso curto com Dados de Vida e descanso longo); fogueira no mapa.
- Mapa novo Bosque do Riacho (layout `forest_brook` no `build_overworld.gd`); entradas `Entrances/*`.
- Placas de estrada com ação `travel:<rota>` e confirmação ([E] confirmar / [Esc] cancelar).
- Suprimentos do grupo (`PartyManager.supplies`, 6 rações iniciais).
- 25 testes novos (total 146).

### Alterado
- `CharacterData` esquema 2 (`hit_dice_spent`) com migração automática do esquema 1.
- `Interactable` ganhou `action`; HUD aceita dica personalizada na caixa de fala.
- Combate iniciado na viagem retorna para a viagem.

## [0.3.1] — 2026-10-24 — Reforma visual

### Adicionado
- `tools/art/`: biblioteca `PixelCanvas` (3 tons, contorno seletivo, sombra) e geradores de personagens,
  terreno e objetos; `build_overworld.gd` monta TileSet, terreno (marching squares) e objetos do mapa.
- Folhas animadas: herói e goblin (4 direções × parado/caminhada/ataque), lobo (2 direções); retrato novo.
- Atlas de terreno com transições e água animada; árvore, pinheiro, arbusto, pedra e placa como objetos.
- `SpriteLibrary` (animações a partir das folhas) e `CombatToken` (combatente animado).
- Combate animado: caminhada entre casas, investida de ataque, dano flutuante, piscar/tremor, queda.

### Alterado
- Jogador usa `AnimatedSprite2D` com direção; marcadores de encontro animados.
- Mapa de teste: camadas `Ground`/`Walls` dentro de `Terrain`, objetos de cenário em `Objects` (y-sort),
  borda de floresta com bloqueio invisível; lago elíptico com praia.
- Tabuleiro de combate com casas de 32 px sobre grama.
- Bíblia visual reescrita para a direção 16 bits.

### Removido
- Arte provisória da Fase 0–3 (`placeholder_*`) e `tools/placeholders/`, substituídas pela nova arte.

## [0.3.0] — 2026-10-24 — Fase 3

### Adicionado
- Regras de combate: `Attack` (ataque, crítico, dano, resistência, bônus de arma, desarmado, distância na grade).
- `Combatant`, `CombatManager` (iniciativa, turnos, movimento, ataques, IA, vitória/derrota/fuga, XP) e `CombatLog`.
- Cena de combate (`scenes/combat/combat_scene.tscn`) com tabuleiro clicável, iniciativa, registro e resultado.
- Monstros (`data/monsters/`: Lobo, Goblin Guerreiro) e encontros (`data/encounters/`), validados pelo registro.
- Autoload `ExplorationManager` e `EncounterTrigger`; dois encontros no mapa de teste.
- Falas com retrato e nome de quem fala; placa lida em voz alta pelo personagem.
- Retrato provisório do herói e sprites do Lobo e do Goblin (catalogados).
- 37 testes novos (total 121).

### Corrigido
- Início de combate removia a cena durante um callback de física.
- Mapa não quebra mais com grupo sem líder válido ao entrar numa área de encontro.

## [0.2.1] — 2026-10-23 — Todas as classes e espécies

### Adicionado
- 10 classes: Bárbaro, Bardo, Clérigo, Druida, Monge, Paladino, Patrulheiro, Feiticeiro, Bruxo, Mago (nível 1).
- 7 espécies: Draconato, Elfo, Gnomo, Golias, Pequenino, Orc, Tiefling.
- 10 armas: Clava, Machadinha, Azagaia, Maça, Bordão, Foice, Lança, Machado Grande, Cimitarra, Arco Longo.
- Defesa sem Armadura (Bárbaro: Con, com escudo; Monge: Sab, sem escudo).
- Campo `extra_skill_options` nas espécies (Sentidos Aguçados do Elfo) e treinamento `martial_light` (Monge).
- Ficha mostra tamanho, visão no escuro e resistências da espécie.
- 11 testes novos (total 84), incluindo as 216 combinações classe × espécie × antecedente.

### Corrigido
- Traços de espécie com nível mínimo apareciam na ficha do nível 1.

## [0.2.0] — 2026-10-23 — Fase 2

### Adicionado
- Motor de regras (SRD 5.2.1): `Ability`, `Skill`, `DiceRoller`, `DiceExpression`, `D20Test`, `RulesEngine`.
- Conteúdo em JSON com validação (`ContentSchema`, `ContentRegistry`, autoload `Content`): Guerreiro, Ladino, Humano, Anão,
  Soldado, Criminoso, 5 armaduras, escudo e 5 armas.
- Personagens: `CharacterData` (serialização versionada), `CharacterFactory` (criação e validação), `CharacterSheet` (ficha derivada).
- Autoload `PartyManager` (grupo entre cenas).
- Tela de criação de personagem com prévia da ficha ao vivo.
- Ficha no mapa (tecla C; Esc fecha) e dica "[C] Ficha" no HUD.
- Tela de Créditos com atribuição do SRD 5.2, aviso de produto não oficial e aviso do Godot.
- Ação de input `character_sheet`.
- 55 testes novos (total 73): regras, dados, conteúdo, criação, serialização, tela de criação, ficha no mapa, créditos.

### Alterado
- "Novo jogo" abre a criação de personagem antes do mapa.
- Exportação Web inclui `data/*.json`.
- Versão 0.1.0 → 0.2.0.

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
