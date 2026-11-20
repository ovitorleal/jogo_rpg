---
onda: livros-de-arghaz
fase-metodologia: 3
estado: AGUARDANDO-APROVACAO
atualizado: 2026-11-20
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
Passo **3 (security)** escrito.
- Risco geral baixo, com 3 contramedidas (CM-LA-01 a 03).
- Um risco aceito pelo responsável: RR-LA-01, os livros do mestre estão públicos no GitHub.
- Falta a aprovação do threat model (`aprovado: true` em `tasks/security/livros-de-arghaz.md`).

Próximo: `/passo-4-code livros-de-arghaz`.

## As fases
| # | Fase | Estado |
|---|---|---|
| 1 | Texto do jogo (crônicas, abertura, cenas, epílogo, diálogos, "Volte até") | ⬜ |
| 2 | Documentos do cânone (`HISTORIA.md` reescrito, perguntas ao mestre) | ⬜ |
| 3 | Peças do Ermo no gerador (sem tocar mapa) | ⬜ |
| 4 | Posição salva segura ao carregar (CM-LA-01) | ⬜ |
| 5 | Ermo nos mapas (Bosque, Clareira; vila só calçamento) | ⬜ |
| 6 | Fechamento (ROADMAP, CHANGELOG, CLAUDE.md; CM-LA-03 na exportação) | ⬜ |

## Tabela de fontes do texto novo
(Preenchida na Fase 1: cada frase nova com livro e capítulo ou seção do compêndio.)

## 📋 Handoff

```
Tarefa: livros-de-arghaz · Crônicas de Arghaz

## Handoff — livros-de-arghaz — passo-3 concluído → passo-4

**Projeto:** jogo_rpg — `C:\Users\ovito\OneDrive\Desktop\jogo_rpg`
**Branch:** `onda/livros-de-arghaz` (publicado; atualizado com o main em 2026-11-20).

**Decisão desta fase:** risco geral baixo; 3 contramedidas. Prioridade: CM-LA-01 (posição salva: só valor finito,
fora do mapa vai para Entrances/*, busca com raio máximo; posição livre = comportamento de hoje), na Fase 4.
CM-LA-02 (sem colchetes BBCode acidentais no texto novo) e CM-LA-03 (pacote Web sem docs/). RR-LA-01: livros do
mestre públicos no GitHub, risco aceito pelo responsável ("Manter público").

**Artefato gerado:** `tasks/security/livros-de-arghaz.md` (aguardando aprovado: true)

**Ler antes de agir:**
1. `tasks/specs/livros-de-arghaz.md` — as 6 fases, a suposição mais arriscada de cada uma, o grep de métrica
2. `tasks/security/livros-de-arghaz.md` — CM-LA-01..03 viram requisitos; plano de teste para o passo 5
3. `docs/livros/` — a fonte de cada frase nova da Fase 1

**Gotchas / decisões não-óbvias:**
- Ids nunca mudam (saves guardam ids); nomes dos companheiros esperam o arquivo do mestre.
- `.docx` do mestre inspecionados: sem macros, embutidos ou links externos.
- `exploration_map.gd` também está na folha de testes-contra-a-morte: reler folha e disco antes da Fase 4.
- llm-routing: Haiku por padrão; Sonnet nas Fases 4 e 5.

**Gate pendente:** aprovação do threat model pelo responsável.

**Próxima ação:**
/passo-4-code livros-de-arghaz
```
