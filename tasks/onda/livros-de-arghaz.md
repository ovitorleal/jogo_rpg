---
onda: livros-de-arghaz
fase-metodologia: 1
estado: AGUARDANDO-APROVACAO
atualizado: 2026-11-07
projeto: jogo_rpg
caminho: C:\Users\ovito\OneDrive\Desktop\jogo_rpg
contratos:
  research: tasks/research/livros-de-arghaz.md
  spec: tasks/specs/livros-de-arghaz.md
  security: tasks/security/livros-de-arghaz.md
---

# 🗺️ PAINEL — livros-de-arghaz

## Onde estamos AGORA
Passo **1 (research)** concluído e aguardando a aprovação do responsável (`aprovado: true` no research).
Próximo: `/passo-2-plan livros-de-arghaz`.

## As fases
(O passo 2 define as sub-fases.)

## 📋 Handoff

```
Tarefa: livros-de-arghaz · Crônicas de Arghaz

## Handoff — livros-de-arghaz — passo-1 concluído → passo-2

**Projeto:** jogo_rpg — `C:\Users\ovito\OneDrive\Desktop\jogo_rpg`
**Branch:** `onda/livros-de-arghaz` (publicado). Outra onda viva: `testes-contra-a-morte` (sem cruzamento).

**Decisão desta fase:** fontes = Livros I e II (mandam) + compêndio (completa). Onde nenhuma fonte dá nome, sai o
nome próprio (só Ione cai; o compêndio sustenta Ribeira, Amara, Garra-Rubra, Vermeth etc.). Reescrever as 6 crônicas,
a abertura, o epílogo e a cena do sonho (Era do Despertar, sem ano; Vermeth, a Brasa Coroada, ativa). Ermo no
cenário do mapa (árvore ancestral, calçamento antigo sob raízes, ruínas), com modelo aprovado antes. Ids não mudam.

**Artefato gerado:** `tasks/research/livros-de-arghaz.md` (aguardando aprovado: true)

**Ler antes de agir:**
1. `tasks/research/livros-de-arghaz.md` — o que cada fonte estabelece, mapa de impacto, pontos para o plano
2. `docs/livros/LEIA-ME.md` e as transcrições `.md` — a fonte de cada frase nova

**Gotchas / decisões não-óbvias:**
- Só texto muda: ids de missão/diálogo/cena/crônica e o nó `Objects/Ione` ficam, senão saves antigos quebram.
- Doran (anão às claras), Ignis (draconato) e Lyra (elfa) conflitam com os livros: listar para o mestre, não decidir.
- Não tocar `tests/party/test_companions.gd` nem `data/monsters/` (estão na folha da outra onda).
- Livro II proíbe inventar números e causas: nada de ano, "3× maior" ou "Segunda Corrente".

**Gate pendente:** aprovação do research pelo responsável.

**Próxima ação:**
/passo-2-plan livros-de-arghaz
```
