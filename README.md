# PROJECT_NAME

RPG 2D de fantasia (nome provisório) feito em **Godot 4.7.2** com GDScript tipado, para navegador desktop.
Especificação completa: [PROJECT_MASTER_SPECIFICATION_FANTASY_RPG_v1.1.md](PROJECT_MASTER_SPECIFICATION_FANTASY_RPG_v1.1.md).

**Estado atual:** Fase 0 (fundação técnica) — veja [docs/ROADMAP.md](docs/ROADMAP.md).

## Requisitos

- Godot 4.7.2-stable (editor padrão, sem .NET): https://godotengine.org/download
- Templates de exportação Web da mesma versão (apenas `web_*` são necessários)
- Python 3 (apenas para servir o build Web localmente)

Nesta máquina o editor está em `C:\Users\ovito\Tools\Godot\`. Exemplos abaixo usam `godot` como atalho para
`Godot_v4.7.2-stable_win64_console.exe`.

## Comandos

```bash
# Importar recursos (necessário após clonar)
godot --headless --path . --import

# Rodar os testes (saída 0 = sucesso)
godot --headless --path . --script res://tests/run_tests.gd

# Executar o jogo no desktop
godot --path .

# Exportar para Web
godot --headless --path . --export-release "Web" exports/web/index.html

# Servir o build Web em http://127.0.0.1:8060
python -m http.server 8060 --bind 127.0.0.1 --directory exports/web
```

O build Web não usa threads, portanto não exige cabeçalhos COOP/COEP do servidor.

## Licenças

- Código e assets próprios: licença **a definir** pelo responsável do projeto.
- Terceiros: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) e [docs/CONTENT_LICENSES.md](docs/CONTENT_LICENSES.md).
- Este projeto não é um produto oficial de Dungeons & Dragons nem afiliado à Wizards of the Coast.
