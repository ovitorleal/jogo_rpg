# As Crônicas de Arghaz

RPG 2D de fantasia no mundo de Arghaz, feito em **Godot 4.7.2** com GDScript tipado, para navegador desktop, com regras
do SRD 5.2.1 (2024). Especificação completa: [PROJECT_MASTER_SPECIFICATION_FANTASY_RPG_v1.1.md](PROJECT_MASTER_SPECIFICATION_FANTASY_RPG_v1.1.md).

**Jogar no navegador:** https://ovitorleal.github.io/jogo_rpg/

**Estado atual:** versão 0.10.0 — aventura "A Garra-Rubra", companheiros recrutáveis e a nova identidade visual
(em andamento). História do mundo em [As Crônicas de Arghaz.md](As%20Cr%C3%B4nicas%20de%20Arghaz.md).
Veja [docs/ROADMAP.md](docs/ROADMAP.md), o roteiro em [docs/VERTICAL_SLICE.md](docs/VERTICAL_SLICE.md) e as limitações
conhecidas em [docs/PUBLISHING.md](docs/PUBLISHING.md).

## Como jogar

- **Novo jogo:** crie o personagem (espécie, classe, antecedente, atributos, aparência, talentos e magias).
- **Objetivo:** aparece sempre no canto superior esquerdo do mapa.
- **Exploração:** WASD ou setas para andar · E, Espaço ou Enter para interagir · C ficha · I inventário · J diário ·
  L escolhas de nível · Esc menu (salvar, voltar ao título).
- **Combate:** clique numa casa azul para mover e num inimigo marcado para atacar; magias e o menu **Ações ▾** trazem
  as características de classe e as opções (Fúria, Golpe Divino, Metamagia...).
- **Salvamento:** automático nos pontos seguros e manual pelo menu (Esc). Fica guardado só neste navegador; limpar os
  dados do site apaga o progresso.

## Requisitos para desenvolver

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

# Exportar e validar o build Web (sem publicar); --deploy publica no GitHub Pages
tools/publish/publish_web.sh

# Servir o build Web em http://127.0.0.1:8060
python -m http.server 8060 --bind 127.0.0.1 --directory exports/web
```

O build Web não usa threads, portanto não exige cabeçalhos COOP/COEP do servidor. Detalhes em
[docs/PUBLISHING.md](docs/PUBLISHING.md).

## Licenças

- Código e conteúdo próprios: **todos os direitos reservados** ([LICENSE](LICENSE)).
- Regras e conteúdo do SRD 5.2.1: CC BY 4.0 (atribuição em Créditos, no jogo).
- Godot Engine: MIT. Terceiros: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) e [docs/CONTENT_LICENSES.md](docs/CONTENT_LICENSES.md).
- Este projeto não é um produto oficial de Dungeons & Dragons nem afiliado à Wizards of the Coast.
