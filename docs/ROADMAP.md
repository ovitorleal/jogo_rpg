# Roadmap

| Fase | Descrição | Estado |
|---|---|---|
| 0 | Fundação técnica | **Concluída** (2026-10-23) |
| 1 | Primeiro mapa | Próxima |
| 2 | Modelo de personagens | — |
| 3 | Combate | — |
| 4 | Viagens e encontros | — |
| 5 | Progressão e conteúdo | — |
| 6 | Salvamento e integração | — |
| 7 | Vertical slice | — |
| 8 | Publicação | — |

## Fase 0 — resultado

- Ambiente: Windows 11, Git 2.51, Godot 4.7.2-stable (instalado em `C:\Users\ovito\Tools\Godot`), templates Web 4.7.2, Python 3.12.
- Projeto abre e importa sem erros; roda no desktop (OpenGL 3.3, Compatibility).
- Testes: 7/7 passando; executor confirmado detectando falhas (teste proposital retornou código 1).
- Exportação Web: `exports/web/` (~40 MB, quase tudo `index.wasm`). Testado em navegador Chromium via
  `http://localhost:8060`: WebGL 2, sem erros no console, botão "Novo jogo" responde.

## Problemas conhecidos

- O projeto está dentro do OneDrive: a sincronização de `.godot/` e `exports/` (ignorados pelo Git, mas não pelo OneDrive) pode gerar
  conflitos de arquivo e tráfego desnecessário. Considerar mover o repositório para fora do OneDrive ou excluir essas pastas da sincronização.
- Persistência de `user://` na Web ainda não verificada (prevista para a Fase 6).
- Tamanho do pacote Web (~40 MB não comprimido) não medido com compressão gzip/brotli da hospedagem.

## Decisões pendentes (responsável do projeto)

- Nome definitivo do jogo (hoje `PROJECT_NAME`).
- Licença do código e dos assets próprios (arquivo `LICENSE` ainda não criado).
- Tamanho-base dos sprites: 32×32 (placeholder atual) ou 48×48 — definir na `ART_BIBLE.md`.

## Próxima tarefa concreta

Fase 1: criar `docs/ART_BIBLE.md` mínima (escala 32 px, paleta provisória), um tileset provisório, um mapa de teste com
`TileMapLayer`, personagem com `CharacterBody2D` (movimento em 4/8 direções, colisão), `Camera2D` seguindo o personagem e
um objeto interativo. Ligar "Novo jogo" ao mapa de teste.
