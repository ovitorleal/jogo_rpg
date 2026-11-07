---
onda: livros-de-arghaz
branch: onda/livros-de-arghaz
aberta_em: 2026-11-07
passo_atual: 1
estado: ativa
migration_reservada: 'nenhuma' # sem banco; ids de missão, diálogo, item e cena NÃO mudam, então o salvamento não muda de esquema
---

## Arquivos e rotas que esta onda toca
- `docs/livros/` — os Livros I e II e o compêndio (docx original + transcrição .md) e um LEIA-ME com a hierarquia das fontes
- `data/lore/chronicles.json` — crônicas reescritas conforme os livros (eras, origem dos povos, dragões)
- `data/story/act1.json` — cenas da Garra e do sonho (Vermeth ativa, em Wyrmgard, não adormecida)
- `data/dialogues/ione.json`, `amara.json`, `companions.json` — só texto (Ione perde o nome próprio)
- `data/quests/*.json`, `data/companions/companions.json` — só texto (`giver`, descrições, epílogo)
- `scripts/ui/character_creation.gd` — texto de abertura (`INTRO_TEXT`)
- `scripts/exploration/exploration_map.gd` — texto do objetivo inicial (linha ~500)
- `tools/art/generate_environment.gd`, `tools/art/build_overworld.gd` — peças do Ermo (árvore ancestral, estrada antiga sob raízes, ruínas em camadas)
- `assets/environments/*`, `assets/asset_catalog.json`, `scenes/world/props/*` — peças novas de cenário
- `scenes/world/forest_brook*.tscn`, `village*.tscn`, `test_map*.tscn` — cenário redistribuído (sem mexer em `Entrances/`, NPCs e encontros)
- `docs/HISTORIA.md`, `docs/VERTICAL_SLICE.md`, `docs/GUIA_DO_MESTRE.md`, `docs/ART_BIBLE.md`, `docs/ROADMAP.md`, `docs/CHANGELOG.md`, `CLAUDE.md`
- testes que conferem texto: `tests/quests/test_vertical_slice.gd`, `tests/story/test_story.gd`, `tests/quests/test_quest_history.gd`
- ⚠️ `tests/party/test_companions.gd` também está na folha de `testes-contra-a-morte`: aqui só a mensagem da asserção da linha 154 cita Ione — **não tocar** (a mensagem não quebra nada)

## Backend — o que esta onda CRIA (🟢 aditivo, não afeta ninguém)
- nenhum (o jogo não tem backend). Fora de backend: peças novas de cenário e a pasta `docs/livros/`.

## 🔴 Backend — o que esta onda ALTERA ou APAGA (⛔ pare e leia)
- nenhuma (sem backend). Fora de backend, **altera texto** de história, diálogos e crônicas e **altera o cenário** de mapas existentes; não altera ids nem o esquema do salvamento.

## Arquivos de controle desta onda
`tasks/research/livros-de-arghaz.md` · `tasks/specs/livros-de-arghaz.md` ·
`tasks/security/livros-de-arghaz.md` · `tasks/onda/livros-de-arghaz.md`
