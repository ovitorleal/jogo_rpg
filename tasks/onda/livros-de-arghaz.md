---
onda: livros-de-arghaz
fase-metodologia: 2
estado: AGUARDANDO-APROVACAO
atualizado: 2026-11-07
projeto: jogo_rpg
caminho: C:\Users\ovito\OneDrive\Desktop\jogo_rpg
contratos:
  research: tasks/research/livros-de-arghaz.md
  spec: tasks/specs/livros-de-arghaz.md
  security: tasks/security/livros-de-arghaz.md
  mockup: tasks/mockups/livros-de-arghaz/index.html
---

# 🗺️ PAINEL — livros-de-arghaz

## Onde estamos AGORA
Passo **2 (plan)** escrito. Decisões D1-D4 e modelo do Ermo **aprovados** pelo responsável (2026-11-07). Falta a
aprovação do spec (`aprovado: true` em `tasks/specs/livros-de-arghaz.md`).
Próximo: `/passo-3-security livros-de-arghaz`.

## As fases
| # | Fase | Estado |
|---|---|---|
| 1 | Texto do jogo (crônicas, abertura, cenas, epílogo, diálogos, "Volte até") | ⬜ |
| 2 | Documentos do cânone (`HISTORIA.md` reescrito, perguntas ao mestre) | ⬜ |
| 3 | Peças do Ermo no gerador (sem tocar mapa) | ⬜ |
| 4 | Posição salva segura ao carregar | ⬜ |
| 5 | Ermo nos mapas (Bosque, Clareira; vila só calçamento) | ⬜ |
| 6 | Fechamento (ROADMAP, CHANGELOG, CLAUDE.md) | ⬜ |

## Tabela de fontes do texto novo
(Preenchida na Fase 1: cada frase nova com livro e capítulo ou seção do compêndio.)

## 📋 Handoff

```
Tarefa: livros-de-arghaz · Crônicas de Arghaz

## Handoff — livros-de-arghaz — passo-2 concluído → passo-3

**Projeto:** jogo_rpg — `C:\Users\ovito\OneDrive\Desktop\jogo_rpg`
**Branch:** `onda/livros-de-arghaz` (publicado; PR #29, não mesclar até o passo 5).

**Decisão desta fase:** 6 fases — 1 texto do jogo, 2 docs do cânone, 3 peças do Ermo no gerador, 4 posição salva
segura, 5 Ermo nos mapas, 6 fechamento. Suposições a atacar primeiro: F1 trocar "Volte a %s" não quebra Amara/Lyra;
F3 o gerador é determinístico (rodar sem mudança e conferir git status); F4 consulta de física em _ready enxerga
os corpos (plano B geométrico); F5 o gerador reproduz as cenas versionadas (rodar sem mudança para user://).
D1-D4 aceitos: "Volte até %s"; tirar Floresta Sussurrante, Ganso Dourado e Martelo do Fundo; sonho sem "minha
garra"; reescrever as falas de Ignis, Lyra e Doran. Modelo do Ermo aprovado.

**Artefato gerado:** `tasks/specs/livros-de-arghaz.md` (aguardando aprovado: true) +
`tasks/mockups/livros-de-arghaz/` (index.html, 3 PNG, `mock_ermo.gd.txt` = referência das peças)

**Ler antes de agir:**
1. `tasks/specs/livros-de-arghaz.md` — fases, blast radius, grep de métrica
2. `tasks/security/livros-de-arghaz.md` — ainda não existe; é o que o passo 3 cria

**Gotchas / decisões não-óbvias:**
- Hoje não há proteção de colisão ao restaurar posição (save_game.gd:226-229, exploration_map.gd:43-45).
- Calçamento = camada Detail sem colisão + RNG separado, senão todas as árvores mudam de lugar.
- `exploration_map.gd` também está na folha de testes-contra-a-morte: reler folha e disco antes da Fase 4.
- Nunca "Primeiro Dragão", nenhum número inventado, Wyrmgard não aparece.

**Gate pendente:** aprovação do spec pelo responsável.

**Próxima ação:**
/passo-3-security livros-de-arghaz
```
