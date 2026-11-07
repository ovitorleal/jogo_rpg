---
onda: testes-contra-a-morte
fase-metodologia: 1
estado: AGUARDANDO-APROVACAO
atualizado: 2026-11-07
projeto: jogo_rpg
caminho: C:\Users\ovito\OneDrive\Desktop\jogo_rpg
contratos:
  research: tasks/research/testes-contra-a-morte.md
  spec: tasks/specs/testes-contra-a-morte.md
  security: tasks/security/testes-contra-a-morte.md
---

# 🗺️ PAINEL — testes-contra-a-morte

## Onde estamos AGORA
Passo **1 (research)** concluído e aguardando a aprovação do responsável (`aprovado: true` no research).
Próximo: `/passo-2-plan testes-contra-a-morte`.

## As fases
(O passo 2 define as sub-fases.)

## 📋 Handoff

```
Tarefa: testes-contra-a-morte · Crônicas de Arghaz

## Handoff — testes-contra-a-morte — passo-1 concluído → passo-2

**Projeto:** jogo_rpg — `C:\Users\ovito\OneDrive\Desktop\jogo_rpg`
**Branch:** `onda/testes-contra-a-morte` (publicado no GitHub). Quadro de obras: 0 ondas vivas além desta.

**Decisão desta fase:** regra do SRD 5.2.1 (p.17-18) feita à mão no motor (`Combatant` + `CombatManager`),
porque não há biblioteca licenciada. Decisões do responsável: morte real com ressurreição paga; só inimigos
inteligentes finalizam caídos (campo `finishes_downed` no monstro, começando pelo chefe goblin); derrota total
volta ao último salvamento. O personagem ganha o campo `dead`, com migração no salvamento.

**Artefato gerado:** `tasks/research/testes-contra-a-morte.md` (aguardando aprovado: true)

**Ler antes de agir:**
1. `tasks/research/testes-contra-a-morte.md` — decisões por problema, mapa de impacto e pontos para o plano
2. `CLAUDE.md` — regras do motor de combate e do salvamento

**Gotchas / decisões não-óbvias:**
- `is_up()` e `living()` têm 75 usos: manter "de pé = PV > 0" e criar estado separado para caído, estável e morto.
- Revivificar hoje funciona em qualquer caído; passa a valer só para morto há até 10 rodadas.
- Remover a adaptação "volta com 1 PV" do `RULES_POLICY` e mudar `test_fallen_allies_get_up_with_one_hp_after_victory`.
- Em aberto para o plano: quem conduz o grupo com o líder morto; preço e lugar da ressurreição (neutro em relação
  ao compêndio do mestre); chance de finalizar; Poupar os Moribundos.

**Gate pendente:** aprovação do research pelo responsável.

**Próxima ação:**
/passo-2-plan testes-contra-a-morte
```
