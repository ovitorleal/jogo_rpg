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
- Placeholders e mapa de teste: ver `docs/ASSET_PIPELINE.md` (`build_test_map.gd --force` apaga edições do editor).
- Exploração: `Interactable` não decide efeitos; o `ExplorationMap` decide. Detalhes em `docs/ARCHITECTURE.md`.
- No navegador, eventos de teclado sintéticos precisam ser despachados no `<canvas>`, não no `window`.
- Versionar arquivos `.uid` e `.import`; não versionar `.godot/` nem `exports/`.
- Nunca afirmar que teste/exportação funcionou sem executar.
- Ao encerrar: atualizar `docs/ROADMAP.md` e `docs/CHANGELOG.md`.
- PowerShell 5.1 corrompe UTF-8 ao reescrever arquivos via `Get-Content`/`Set-Content`: use as ferramentas Edit/Write.
