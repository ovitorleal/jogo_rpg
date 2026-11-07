---
feature: livros-de-arghaz
onda: livros-de-arghaz
fase: plan
data: 2026-11-07
projeto: As Crônicas de Arghaz
branch: onda/livros-de-arghaz
migration: nenhuma (sem banco; o salvamento não muda de esquema)
research: tasks/research/livros-de-arghaz.md
mockup: tasks/mockups/livros-de-arghaz/index.html
aprovado: false
llm-routing:
  proxima-fase: passo-3-security
  modelo: claude-haiku-5-5
  thinking: false
  effort: baixo
  justificativa: "Sem rede, sem conta, sem dado pessoal e sem esquema novo; a superfície é texto, arte gerada por script e um ajuste de posição ao carregar o save."
---

# Spec — Livros de Arghaz

## Requisitos (restate)
Todo texto que o jogador vê passa a seguir os Livros I e II, com o compêndio completando onde os livros não falam:
- saem o ano, as eras inventadas, o "Silêncio" e o nome Ione;
- Vermeth passa a ser a Brasa Coroada, acordada.

Ids não mudam. O Ermo entra no cenário do Bosque do Riacho e da Clareira, com peças novas do gerador, só depois que o
responsável aprovar a imagem real. Quem já tem save carrega, continua e nunca nasce preso dentro de um objeto novo.

Ligação com o PRD (`tasks/PRD.md`): a história é do mestre, e o jogo apresenta o mundo dele, não um inventado.

## Decisões do responsável antes do código
Achadas no plano; não reabrem nada do research. **Todas decididas por Vitor Leal em 2026-11-07: a recomendação de cada linha foi aceita.**

| # | Ponto | Recomendação |
|---|---|---|
| D1 | A frase "Volte a %s" (`quest_log.gd:54,71`, "Voltar a %s" em `journal_panel.gd:50`) ficaria "Volte a a chefe da vila" | Trocar por "Volte até %s" e "Voltar até %s". Duas expectativas de teste mudam ("Volte a Amara" passa a "Volte até Amara") |
| D2 | Mais três nomes sem fonte: "Floresta Sussurrante" (região, rota, placa, tela final, Lyra), "Estalagem do Ganso Dourado" (`companion_roster.gd:9`, placa da vila) e "Martelo do Fundo" (fala do Doran) | Mesma regra de Ione: descrição no lugar ("a floresta", "a estalagem de Ribeira") |
| D3 | No sonho, "Você trouxe **minha** garra" afirma posse da Garra por Vermeth; o compêndio §12 guarda essa ligação como mistério | Tirar a posse: Vermeth **reconhece** a Garra e quer encontrá-la |
| D4 | Três falas de companheiros inventam lore: Ignis ("a Linhagem Vermelha nunca morreu: só dorme"), Lyra ("chamado da escama") e Doran ("Martelo do Fundo") | Reescrever as três dentro das cenas (já no escopo) |

## Fases

### Fase 1 — Texto do jogo
- **Arquivos:**
  - dados: `data/lore/chronicles.json`, `data/story/act1.json`, `data/quests/main_quest.json`, `data/dialogues/ione.json`, `data/dialogues/amara.json`, `data/dialogues/companions.json`, `data/companions/companions.json`;
  - código: `scripts/ui/character_creation.gd` (`INTRO_TEXT`), `scripts/exploration/exploration_map.gd:500` (só a string do objetivo), `scripts/quests/quest_log.gd` e `scripts/ui/journal_panel.gd` (D1);
  - cena: `scenes/world/npc_ione.tscn` (só o `prompt_text`, "Conversar com Ione");
  - com D2: `data/regions/regions.json`, `data/routes/routes.json`, `scripts/party/companion_roster.gd`, `scripts/menus/ending_screen.gd`, `scenes/world/test_map.tscn:39`, `scenes/world/village.tscn:36`;
  - testes: `tests/quests/test_vertical_slice.gd`, `tests/story/test_story.gd`, `tests/quests/test_quest_history.gd`, `tests/quests/test_quests_dialogue.gd`.
- **Não tocar:** `tests/party/test_companions.gd` (a asserção compara id; só a mensagem cita Ione).
- **Regras do texto:**
  - cada frase nova cita a fonte (livro e capítulo, ou seção do compêndio) numa tabela no painel da onda;
  - nenhum número inventado;
  - nunca "Primeiro Dragão";
  - Wyrmgard não é citada nem localizada;
  - âncoras que os testes exigem e as fontes sustentam: "oferendas", o falante "Uma voz no sonho", "Vermeth" no título da crônica, "Vessa", "Continua no Ato II", "garra vermelha" na escolha do herói.
- **Automático:**
  - a suíte de testes sai com 0;
  - o grep de métrica (abaixo) em `data/`, `scripts/` e `scenes/` não acha texto visível ao jogador;
  - `git diff` sem nenhuma linha `"id":` alterada.
- **Manual:** o responsável lê no jogo a abertura, as 6 crônicas, as 2 cenas e o epílogo, conferindo com a tabela de fontes.
- **Suposição mais arriscada:** trocar o texto do `giver` não afeta outra missão (Amara e Lyra também são `giver`). Começar pelos testes de "Volte a Amara".
- **Blast radius:** só texto exibido.

  | População | O que sente |
  |---|---|
  | Novo | Abertura sem ano, chefe sem nome, crônicas novas |
  | Save antigo | Mesmo progresso; crônicas já lidas com texto novo; sonho visto não repete (`once_events`) |
  | Borda | Save com missão pronta para entregar mostra "Volte até a chefe da vila" |

  **Não muda:** ids, esquema do save, condições de desbloqueio, recompensas, o nó `Objects/Ione`, `npc_ione.tscn` como arquivo.

### Fase 2 — Documentos do cânone
- **Arquivos:**
  - `docs/HISTORIA.md`, reescrito como resumo do cânone com remissão a `docs/livros/`; a proposta antiga vai para `docs/arquivo/HISTORIA-proposta-0.11.md`;
  - `docs/VERTICAL_SLICE.md` e `docs/GUIA_DO_MESTRE.md` (nomes e eras);
  - perguntas ao mestre:
    - Doran, anão às claras;
    - Ignis, draconato fora de Wyrmgard;
    - Lyra, elfa fora de Althelas;
    - as descrições de espécie em `data/species/species.json:122` ("magia feérica") e `:199` ("herdeiros dos titãs");
    - o D2, se não for aprovado.
- **Automático:** o grep de métrica não acha nada em `docs/HISTORIA.md`. `docs/CHANGELOG.md` não é reescrito, porque é histórico.
- **Manual:** o responsável aprova o resumo.
- **Suposição mais arriscada:** o resumo inventar ligações causais. Mitigação: cada parágrafo cita a fonte.
- **Blast radius:** só documentos.

### Fase 3 — Peças do Ermo (sem tocar mapa)
- **Arquivos:**
  - `tools/art/generate_environment.gd`, com as funções novas `_ancestral_tree`, `_young_tree`, `_sapling`, `_wall_base`, `_fallen_column` e os ladrilhos de calçamento antigo; elas portam o modelo aprovado;
  - PNG novos em `assets/environments/` com `.import`;
  - `scenes/world/props/{ancestral_tree,young_tree,sapling,wall_base,fallen_column}.tscn` com `.uid`;
  - `assets/asset_catalog.json` e `docs/ART_BIBLE.md` (rampas "pedra antiga", "casca antiga", "folhagem antiga").
- **Atlas:** só a área livre recebe ladrilhos novos (linha 0, colunas 6-15). Nada já existente se move. Corrigir o cabeçalho desatualizado do gerador.
- **Automático:**
  - regenerar deixa `tree.png`, os ícones e o resto byte a byte iguais (o `git status` só mostra arquivos novos e o atlas);
  - comparação por região: os ladrilhos antigos do atlas ficam idênticos;
  - suíte verde.
- **Manual:** as peças batem com `tasks/mockups/livros-de-arghaz/ermo_pecas.png`.
- **Suposição mais arriscada:** o gerador ser determinístico. Rodar **sem mudança** e conferir o `git status` antes de escrever qualquer peça.
- **Blast radius:** só arquivos novos e a área livre do atlas; nenhum jogador sente nada até a Fase 5.

### Fase 4 — Posição salva segura (antes de mexer em mapa)
- **Arquivos:**
  - `scripts/exploration/exploration_map.gd`: só o ramo `if back is Vector2:` (linhas 43-45) e uma função privada nova;
  - teste novo `tests/exploration/test_safe_spawn.gd`.
- **Comportamento:**
  - só quando a posição restaurada (save ou volta de combate) cai sobre colisão de objeto ou de ladrilho de muro/água, procurar a célula livre mais próxima em anéis de 16 px;
  - sem vaga no raio, ir ao primeiro `Entrances/*`;
  - posição livre: comportamento idêntico ao de hoje.
- **Evidência do risco:** hoje não existe proteção. `save_game.gd:226-229` restaura a posição crua, `exploration_manager.gd:77-81` só a devolve e `exploration_map.gd:43-45` a aplica sem teste.
- **Automático:** o teste põe o jogador sobre uma árvore conhecida e ele sai; numa posição livre ele não é movido. Suíte verde.
- **Suposição mais arriscada:** uma consulta de física em `_ready` já enxergar os corpos estáticos. Plano B, determinístico: testar contra os `CollisionShape2D` de `Objects/Props` e as células de `Walls`.
- **Blast radius:**
  - `exploration_map.gd` também está na folha de `testes-contra-a-morte` (membro morto, em outro trecho). Antes de escrever, reler `tasks/obras/` e `git diff main...onda/testes-contra-a-morte -- scripts/exploration/exploration_map.gd`.
  - Save antigo: nada muda, salvo posição bloqueada.
  - Não muda: chegada por `Entrances` e encontros.

### Fase 5 — Ermo nos mapas (só com o modelo aprovado)
- **Arquivos:**
  - `tools/art/build_overworld.gd`: peças novas em `PROP_SCENES`, uma camada `Detail` sem colisão para o calçamento, **um RNG separado** para as peças novas (chamado depois do espalhamento atual) e zonas protegidas;
  - regenerados: `assets/tilesets/overworld_tileset.tres`, `scenes/world/forest_brook_{terrain,props}.tscn`, `scenes/world/test_map_{terrain,props}.tscn` e `scenes/world/village_terrain.tscn` (vila: só calçamento, sem colisão; `village_props.tscn` não muda).
- **Regras que protegem o que existe:**
  - o calçamento é camada de enfeite, não tipo de terreno. Se fosse terreno, a sequência aleatória mudaria e todas as árvores trocariam de lugar;
  - peças novas usam RNG próprio;
  - árvore comum só vira árvore jovem no mesmo ponto, com colisão menor ou igual;
  - zonas protegidas: os retângulos `CLEAR`, mais 2 ladrilhos ao redor de cada `Entrances/*`, `Interactable`, `EncounterTrigger`, do início do `Player` e da ruína.
- **Automático:**
  - teste de preservação: todo objeto antigo com mesmo nome, tipo e posição, exceto as trocas deliberadas;
  - teste de zonas: nenhuma colisão nova nas zonas protegidas;
  - `test_slice_world_is_connected` verde;
  - suíte verde;
  - exportação Web sem erro.
- **Manual:** captura real dos três mapas comparada com o modelo aprovado e uma caminhada do oeste até o acampamento.
- **Suposição mais arriscada:** o gerador atual reproduzir as cenas versionadas. Rodar **sem mudança** para `user://` e comparar com o versionado; se diferir, portar as edições para o layout antes.
- **Blast radius:**
  - toca o cenário de 3 mapas e o TileSet compartilhado; as coordenadas antigas não mudam;
  - novo vê o Ermo;
  - save antigo vê o Ermo, e a Fase 4 cobre a posição salva;
  - não muda: `Entrances`, NPCs, placas, encontros, fogueira, água, areia, terra e objetos da vila.

### Fase 6 — Fechamento
- **Arquivos:** `docs/ROADMAP.md`, `docs/CHANGELOG.md` e `CLAUDE.md` (camada `Detail`, RNG separado, "livros mandam" e o caminho `docs/livros/`).
- **Automático:** suíte verde, exportação Web, grep de métrica zerado e uma sonda que carrega um save do meio do Ato I gravado **antes** da onda e chega ao fim do ato.

## Grep de métrica (texto visível ao jogador)
`Ione"|Ione,|com Ione|a Ione|1\.214|Era dos Homens|Era da Criação|Brasa que Dorme|Primeiro Dragão|Silêncio dos|O Silêncio|desde o Silêncio|Guerra das Escamas|Segunda Corrente`
(e, com D2: `Floresta Sussurrante|Ganso Dourado|Martelo do Fundo`). Fora do grep:
- nomes internos: `dialogue.ione`, `npc_ione`, `OUT_IONE`, notas do catálogo;
- a interjeição "Silêncio... ouviu?" de Lyra.

## Bibliotecas × hand-rolled
Nenhuma biblioteca em nenhuma fase:
- texto: reescrita a partir das fontes do mestre;
- arte: o pipeline próprio (`PixelCanvas`), exigido pela `ART_BIBLE` (nada copiado);
- posição segura: consulta de física do Godot ou geometria das formas.

## Riscos
| Risco | Mitigação |
|---|---|
| Texto "fiel" que ainda inventa | Tabela frase a frase com a fonte; review confere; mistérios do compêndio §12 preservados |
| Visual reprovado (já aconteceu duas vezes) | Modelo real aprovado antes; peças fora dos mapas até lá; reverter é regerar |
| `--force` apagar edições do editor | Teste de reprodução antes (Fase 5) |
| Sequência aleatória mudar a floresta inteira | Camada `Detail` + RNG separado + teste de preservação |
| TileSet compartilhado quebrar a vila | Ladrilhos só na área livre; comparação por região |
| Conflito em `exploration_map.gd` com a outra onda | Trecho isolado; reler folha e disco antes |
| "Volte a a chefe" | D1 |

**Complexidade:** média. Fases 1, 3 e 5 médias; 2, 4 e 6 pequenas. Duas a três sessões, com os gates D1-D4, modelo do
Ermo e spec.

## O que NÃO estamos fazendo
- Mudar ids, esquema do save, missões, encontros, recompensas ou regras.
- Personagens, retratos, sprites, `generate_characters.gd`.
- Telas de título, viagem e combate.
- Ato II, cidades do compêndio, missões novas.
- Leitura dos livros dentro do jogo.
- Resolver Doran, Ignis, Lyra e as descrições de espécie (vão para o mestre).
- Trocar os nomes dos 6 companheiros. **Decisão do responsável (2026-11-07):** os nomes ficam como estão até o
  mestre mandar a lista, pedida em `Nomes_para_o_Mestre.docx`, que também oferece nomear a chefe da vila, a
  floresta, a estalagem e o deus do Doran. Quando a resposta chegar, trocar só o nome exibido (ids e saves não
  mudam). Amara fica porque está no compêndio.
- Tocar `tests/party/test_companions.gd` e `data/monsters/`.
- Reescrever `docs/CHANGELOG.md`.

## Gate de mockup
**ATIVO** (a onda muda o cenário visível). O modelo está em `tasks/mockups/livros-de-arghaz/` (`index.html` e três
PNG), gerado pelo pipeline real; o script fica em `mock_ermo.gd.txt` como referência da Fase 3. **Aprovado pelo responsável em 2026-11-07.** O checklist anti-IA foi rodado na página: sem eyebrow, emoji,
selo, card dentro de card ou copy-poema; o texto cita as fontes. 

## Status
- [x] Requisitos, fases com critérios automático e manual, anti-escopo
- [x] Arquivos exatos por fase, suposição mais arriscada, blast radius e três populações
- [x] Folha de obra completada; migration: nenhuma; branch `onda/livros-de-arghaz`
- [x] Modelo gerado
- [x] Decisões D1-D4 do responsável (recomendações aceitas, 2026-11-07)
- [x] Modelo do Ermo aprovado (Vitor Leal, 2026-11-07); script do modelo em `tasks/mockups/livros-de-arghaz/mock_ermo.gd.txt`
- [ ] Spec aprovado

aprovado: false
