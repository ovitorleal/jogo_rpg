---
onda: testes-contra-a-morte
branch: onda/testes-contra-a-morte
aberta_em: 2026-11-07
passo_atual: 1
estado: ativa
migration_reservada: 'nenhuma' # sem banco; o salvamento local muda de esquema (personagem morto), com migração no SaveGame
---

## Arquivos e rotas que esta onda toca
- `scripts/combat/combat_manager.gd` — testes contra a morte, dano a 0 PV, dano massivo, estabilizar, IA que finaliza caídos, fim do "volta com 1 PV"
- `scripts/combat/combatant.gd` — estado de morte (sucessos, falhas, estável, morto)
- `scripts/combat/combat_scene.gd` — mostrar testes contra a morte; derrota com "carregar último salvamento"
- `scripts/characters/character_data.gd` — campo `dead` (personagem morto fora do combate), com migração
- `scripts/save/save_game.gd` — validar e migrar o campo novo
- `scripts/exploration/exploration_manager.gd` — derrota volta ao último salvamento em vez de apagar a partida
- `scripts/exploration/exploration_map.gd`, `scripts/ui/party_frames.gd`, `scripts/exploration/party_follower.gd` — membro morto (retrato, seguidor, encontros)
- `data/monsters/*.json` — marca de quem finaliza caídos
- `data/spells/spells.json` — Revivificar (só morto há pouco tempo); talvez Poupar os Moribundos
- `docs/RULES_POLICY.md`, `docs/ROADMAP.md`, `docs/CHANGELOG.md`, `tests/combat/*`, `tests/party/test_companions.gd`

## Backend — o que esta onda CRIA (🟢 aditivo, não afeta ninguém)
- nenhum (o jogo não tem backend)

## 🔴 Backend — o que esta onda ALTERA ou APAGA (⛔ pare e leia)
- nenhuma (sem backend). Fora de backend, a onda **altera o esquema do salvamento** (campo novo no personagem), com migração.

## Arquivos de controle desta onda
`tasks/research/testes-contra-a-morte.md` · `tasks/specs/testes-contra-a-morte.md` ·
`tasks/security/testes-contra-a-morte.md` · `tasks/onda/testes-contra-a-morte.md`
