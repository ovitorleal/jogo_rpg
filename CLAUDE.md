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
- Testes novos: `tests/**/test_*.gd`, estendendo `res://tests/base_test.gd`.
- Todo asset novo entra em `assets/asset_catalog.json` com origem e licença.
- Versionar arquivos `.uid` e `.import`; não versionar `.godot/` nem `exports/`.
- Nunca afirmar que teste/exportação funcionou sem executar.
- Ao encerrar: atualizar `docs/ROADMAP.md` e `docs/CHANGELOG.md`.
- PowerShell 5.1 corrompe UTF-8 ao reescrever arquivos via `Get-Content`/`Set-Content`: use as ferramentas Edit/Write.
