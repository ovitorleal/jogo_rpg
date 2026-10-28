# CLAUDE.md

RPG 2D de fantasia em Godot 4.7.2 + GDScript tipado, exportado para Web (Compatibility/WebGL 2).
Especificação mestra: `PROJECT_MASTER_SPECIFICATION_FANTASY_RPG_v1.1.md` — leia as seções relevantes antes de cada tarefa.

## Comandos (Windows)

- Godot: `C:\Users\ovito\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`
- Testes: `<godot> --headless --path . --script res://tests/run_tests.gd` (saída ≠ 0 = falha)
- Importar: `<godot> --headless --path . --import`
- Exportar Web: `<godot> --headless --path . --export-release "Web" exports/web/index.html`
- Servir build: configuração `web-build` em `.claude/launch.json` (porta 8060)

## Regras de trabalho

- Uma fase/tarefa por vez; estado e próxima tarefa em `docs/ROADMAP.md`.
- Regras de RPG só no motor de regras (`scripts/rules/`), nunca na UI. Base: SRD 5.2.1 (2024); não misturar com 2014.
  Registrar regra, fonte e adaptação em `docs/RULES_POLICY.md`. Aleatoriedade só via `DiceRoller`.
- Conteúdo novo: JSON em `data/<tipo>/` com `source`; esquema em `ContentRegistry.TYPES`; ids estáveis com prefixo do tipo.
- Personagem salvo = `CharacterData.to_dict()`; ao carregar, sempre `from_dict` + `CharacterFactory.validate`.
- GDScript: `Array[T] + Array[T]` perde o tipo; use `append_array` para manter `Array[StringName]`.
- Testes novos: `tests/**/test_*.gd`, estendendo `res://tests/base_test.gd`.
- Todo asset novo entra em `assets/asset_catalog.json` com origem e licença; escala e paleta em `docs/ART_BIBLE.md`.
- Arte e mapa de teste gerados por `tools/art/` (ver `docs/ASSET_PIPELINE.md`); `build_overworld.gd --force` apaga
  edições do editor. Estilo e paleta em `docs/ART_BIBLE.md`; nada copiado de jogos existentes.
- Jogo: **As Crônicas de Arghaz**. Arte nova (ilustrações geradas com ChatGPT pelo responsável) em `art_source/arghaz/`,
  importada por `tools/art/import_arghaz.gd`; o que falta está em `art_source/PEDIDOS_DE_ARTE.md`. Não gere arte
  "no estilo" por código: peça ao responsável. Interface: tema `assets/ui/arghaz_theme.tres` (`build_ui_theme.gd`).
- Aparência: o personagem usa a ilustração da espécie vestida para a classe (`<espécie>_<classe>.png`; sem ela, a
  espécie) via `Appearance.figure_path/figure_for`; companheiro pode ter `figure`.
  O `CharacterPainter` é só reserva. Use `Appearance.sheet_texture/portrait_texture`, nunca a folha fixa do herói.
- Sprites: ilustrações de pose única viram animações por código (`SpriteLibrary.frames_for_figure`); folhas antigas
  têm 9 colunas (parado 0-1, caminhada 2-5, ataque 6-8). Sempre use `SpriteLibrary.attach(sprite, frames)`.
- Mapas com fundo pintado: nó `Backdrop` (`MapBackdrop`, `map_rect`); tiles e adereços viram só colisão.
- Verificação visual: o painel do navegador pode estar pausado; prefira uma sonda com janela real que salva
  `root.get_texture().get_image()` no scratchpad.
- Exploração: `Interactable` não decide efeitos; o `ExplorationMap` decide. Detalhes em `docs/ARCHITECTURE.md`.
- Combate: estado só muda via `CombatManager.submit()`/`run_enemy_turn()`; a cena só exibe eventos. Nos testes,
  `ExplorationManager.scene_changes_enabled = false` e `ai_delay = 0`; sempre restaurar no fim do teste.
- Nunca trocar de cena dentro de callback de física (use `call_deferred`).
- Viagem: estado só muda via `TravelSystem`; a tela guarda o estado em `ExplorationManager.store_travel()`.
  Nos testes use `roller_override` para dados determinísticos.
- Missões e diálogos: dados em `data/quests/` e `data/dialogues/`; progresso só via `QuestManager.notify*`.
  A missão `final: true` fecha a aventura (tela de conclusão); roteiro da fatia em `docs/VERTICAL_SLICE.md`.
  Inventário do grupo em `PartyManager.inventory`; equipamento em uso fica no `CharacterData`.
- Companheiros: dados em `data/companions/`; recrutar só via ação de diálogo `recruit:` / `CompanionRoster`
  (`PartyManager.roster`, grupo máximo `MAX_PARTY`). NPC no mapa = `npc_companion.tscn` com `companion_id`.
- Características/talentos: dados em `data/classes`, `data/subclasses`, `data/feats` (campo `grants` gera escolhas em
  `CharacterChoices`; recursos em `ClassFeatures`). Ao ligar uma característica no motor, mude `implemented` para true.
- Magias: regras em `Spellcasting` (`scripts/rules/`), dados em `data/spells/` (efeito e estilo visual por magia),
  resolução no `CombatManager` (comando `cast`); efeitos visuais em `SpellVfx`. Classes de regras não usam autoloads.
- Salvamento: só via `SaveManager` (um slot; `request_autosave` em pontos seguros, `save_now` manual). Estado novo que
  precise persistir entra em `SaveGame.capture/validate/apply` (com migração se mudar o esquema). Cenas que permitem
  salvar expõem `save_blocker()`. Nos testes o executor já usa `user://test_save` e desliga o autosave.
- O executor de testes reprova erros de script em tempo de execução (Logger); não use `push_error` para "falhas esperadas" que
  devam reprovar — use asserções.
- Mapas novos: layout em `tools/art/build_overworld.gd` (`--layout <nome>`), cena com `%Terrain`, `Entrances/`, `Objects`.
- O painel do navegador é compartilhado com o desenvolvedor: avisar antes de testar nele.
- No navegador, eventos de teclado sintéticos precisam ser despachados no `<canvas>`, não no `window`.
- Versionar arquivos `.uid` e `.import`; não versionar `.godot/` nem `exports/`.
- Nunca afirmar que teste/exportação funcionou sem executar.
- Ao encerrar: atualizar `docs/ROADMAP.md` e `docs/CHANGELOG.md`.
- PowerShell 5.1 corrompe UTF-8 ao reescrever arquivos via `Get-Content`/`Set-Content`: use as ferramentas Edit/Write.
