---
feature: testes-contra-a-morte
onda: testes-contra-a-morte
fase: research
data: 2026-11-07
projeto: As Crônicas de Arghaz
aprovado: false
llm-routing:
  proxima-fase: passo-2-plan
  modelo: claude-sonnet-5-5
  thinking: true
  effort: medio
  justificativa: "Onda padrão (4-5 sub-fases) numa stack conhecida, mas muda o esquema do salvamento e o fluxo de derrota; pede planejamento cuidadoso, sem integração externa."
---

# Research — Testes contra a morte

## Contexto e Motivação

Hoje, um personagem a 0 PV apenas sai do combate. Se o grupo vence, quem caiu "levanta com 1 PV", uma adaptação
provisória registrada em `docs/RULES_POLICY.md`. Se todos caem, é derrota: o jogo volta ao título e a partida em
andamento se perde. A onda troca isso pela regra do **SRD 5.2.1**: inconsciência, testes contra a morte,
estabilização, dano massivo e morte real com ressurreição. O combate fica mais tenso e tático, e a regra
central que faltava deixa de ser uma adaptação. Não depende da história do mestre.

**Referência no PRD:** `tasks/PRD.md` ("Regras do SRD 5.2.1, sem misturar com a edição de 2014").

## Fase 0 — Compreensão

### Restate
Implementar no combate a regra do SRD 5.2.1 para quem chega a 0 PV:
- o personagem fica Inconsciente e rola testes contra a morte;
- pode ser estabilizado ou curado;
- pode morrer por falhas ou por dano massivo, e a morte persiste até uma ressurreição paga;
- a derrota total passa a voltar ao último salvamento, sem apagar a partida.

### Pressupostos
1. `[ASSUMIDO ÓBVIO]` Só personagens rolam testes contra a morte; monstros morrem a 0 PV (SRD: "Monster Death").
2. `[ASSUMIDO ÓBVIO]` O combate continua enquanto houver um membro do grupo de pé.
3. `[ASSUMIDO ÓBVIO]` O dano massivo do SRD entra junto.
4. `[ASSUMIDO ÓBVIO]` Quem está caído, mas vivo, no fim de um combate vencido acorda com 1 PV (o SRD dá 1 PV
   depois de 1d4 horas; o tempo é encurtado).
5. `[VERIFICADO]` A morte é real, com ressurreição paga.
6. `[VERIFICADO]` Só inimigos inteligentes finalizam quem está caído.
7. `[VERIFICADO]` A derrota total volta ao último salvamento.

### Gaps respondidos pelo usuário (2026-11-07)

| Pergunta | Resposta |
|---|---|
| O que acontece quando um personagem morre de verdade? | **Morte real, ressurreição paga.** O companheiro morto não luta até ser revivido (Revivificar do grupo ou serviço pago). O herói morto, com o grupo vivo: o grupo segue até revivê-lo. |
| Os inimigos atacam quem já está caído? | **Só os inteligentes.** Feras e goblins comuns atacam quem está de pé; chefes e inimigos espertos às vezes finalizam um caído. |
| E quando o grupo inteiro cai? | **Volta ao último salvamento**, com uma tela de derrota que oferece carregar o salvamento automático, em vez de apagar tudo. |

### Anti-escopo
- Animações de queda, de morte e de estabilização: ficam para a onda 3 (combate mais vivo). Esta onda mostra o
  estado por texto, ícone e retrato.
- Condições novas além de Inconsciente (que já existe na tabela de condições).
- IA dos companheiros.
- Morte fora de combate (armadilhas, fome): não existe dano fora do combate hoje.
- Cenário e NPC da ressurreição com peso narrativo: a localização é decidida no plano de forma neutra, para não
  contradizer o compêndio do mestre.

### Pre-mortem (erros de ondas anteriores para não repetir)
1. **Estado novo sem migração quebra saves antigos.** Já aconteceu com o histórico de missões, e a correção foi
   aceitar o campo ausente. O campo `dead` precisa de padrão `false` e entrar no `SaveGame.validate`.
2. **Regra fora do motor.** As regras ficam no `CombatManager` e no `Combatant`; a cena só exibe eventos
   (CLAUDE.md).
3. **Afirmar que funciona sem rodar.** Testar com `DiceRoller.scripted`, rodar a suíte inteira e o CI.
4. **Adaptação silenciosa.** Toda adaptação (o tempo de 1d4 horas encurtado, a ressurreição paga) é registrada
   em `docs/RULES_POLICY.md`.
5. **Visual com cara de "procedural estranho".** O usuário já rejeitou efeitos assim. Esta onda se limita a
   ícones e texto claros; o polimento fica para a onda 3.

## Estado Atual da Codebase

- `scripts/combat/combatant.gd:75` — `is_up()` é só `hp > 0`. Não há distinção entre caído, estável e morto.
- `scripts/combat/combat_manager.gd:156` — `living(team)` filtra por `is_up()`. É usado em 33 pontos no
  `CombatManager` e em 42 fora dele (turnos, alvos, fim de combate, áreas de magia).
- `scripts/combat/combat_manager.gd:1017-1021` — `_check_end`: vitória sem inimigos vivos; derrota sem membros
  do grupo de pé.
- `scripts/combat/combat_manager.gd:404-412` — `apply_results_to_party`: depois da vitória, quem caiu levanta
  com 1 PV (a adaptação que esta onda remove).
- `scripts/combat/combat_manager.gd:959` — `_advance_turn`: onde entra o teste contra a morte no início do turno.
- `scripts/combat/combat_manager.gd:1597` — `_apply_damage`: onde entram a falha por dano a 0 PV, as duas falhas
  por crítico e o dano massivo.
- `scripts/combat/combat_manager.gd:1746` — `_choose_target`: a IA escolhe o alvo mais próximo entre os
  `living()`. Hoje, nunca mira um caído.
- `scripts/combat/combat_manager.gd:1129-1131, 1448` — a resolução `revive` (Revivificar) hoje funciona em
  qualquer aliado caído; com a regra nova, só em quem morreu há pouco tempo.
- `scripts/combat/combat_manager.gd:35-37, 329` — a condição `unconscious` já existe (nome e efeito de falhar
  testes de Força e Destreza), mas não é aplicada a 0 PV.
- `scripts/exploration/exploration_manager.gd:65-69` — derrota: `reset()`, `PartyManager.clear()`,
  `QuestManager.reset()` e volta ao título (a partida se perde).
- `scripts/combat/combat_scene.gd:272` — só personagens com `current_hp > 0` entram no combate.
- `scripts/characters/rest.gd:15` — quem está a 0 PV não gasta Dados de Vida.
- `scripts/exploration/exploration_map.gd:669` — líder a 0 PV não entra em encontro ("não há ninguém para lutar").
- Dados: `spell.cure_wounds`, `spell.healing_word` e `spell.revivify` existem; `spell.spare_the_dying` (Poupar
  os Moribundos, truque do SRD) não existe.
- Padrões: regras no motor, eventos para a cena, dados determinísticos com `DiceRoller.scripted`.

## Estado atual e impacto (engenharia reversa)

**(a) Consumidores reais do que muda:**
- `is_up()` e `living()`: 75 usos. A semântica "de pé = PV > 0" continua; o que muda é que um caído vivo
  precisa de um estado separado (`stable`, `dead`) para os testes, a IA e o fim do combate.
- `Combatant.hp == 0` de um personagem: hoje significa "fora". Passa a significar "inconsciente", e
  `dead == true`, "morto".
- `CharacterData.current_hp`: lido pelo combate, pelo descanso, pelos retratos e pelo mapa.

**(b) Estado pré-existente nos dados reais (salvamentos):**
- Nenhum salvamento tem o campo `dead`. **Todos os personagens existentes devem ler como vivos** (padrão
  `false`).
- Um salvamento pode ter personagem com `current_hp = 0` fora do combate? Pela regra atual, não: a vitória
  devolve 1 PV e a derrota apaga a partida. É seguro tratar `current_hp = 0` com `dead = false` como "caído",
  que acorda com 1 PV.

**(c) O que quem já usa sente:**
- **Jogador com o jogo em andamento:** nada muda até o próximo combate.
- **No combate:** quem cai passa a rolar testes contra a morte, em vez de esperar o fim da luta.
- **Na derrota:** em vez de perder a partida, volta ao último salvamento.
- **Testes:** `tests/party/test_companions.gd::test_fallen_allies_get_up_with_one_hp_after_victory` e os testes
  de derrota em `tests/combat/test_combat_manager.gd` mudam de expectativa.

## Pesquisa Externa

### Regra oficial (fonte primária)

- **SRD 5.2.1** (Wizards of the Coast, CC BY 4.0), PDF oficial em
  https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf, lido em 2026-11-07:
  - **Páginas 17-18, "Dropping to 0 Hit Points":**
    - morte instantânea de monstros (com a exceção a critério do mestre);
    - dano massivo: o restante, depois de zerar os PV, igual ou maior que os PV máximos;
    - Inconsciente até recuperar PV;
    - testes contra a morte no início do turno: d20, 10 ou mais é sucesso, três de um tipo encerra;
    - 1 natural conta duas falhas; 20 natural recupera 1 PV;
    - dano a 0 PV é uma falha (crítico, duas; dano igual ou maior que o máximo, morte);
    - estabilizar: ação Ajudar com teste de Sabedoria (Medicina) CD 10. Estável não rola testes, volta a rolar se
      levar dano e recupera 1 PV depois de 1d4 horas.
  - **Glossário, "Unconscious":** Incapacitado e Caído, deslocamento 0, ataques contra ele com vantagem, falha
    automática em testes de Força e Destreza, e acerto a até 1,5 m (5 pés) vira crítico.
  - **Glossário, "Dead":** só volta com magia, como Revivificar ou Reviver os Mortos.
  - **Revivificar:** 3º círculo, uma ação, morte no último minuto, diamante de 300+ PO consumido, volta com 1 PV.
  - **Reviver os Mortos:** 5º círculo, 1 hora, morte há até 10 dias, diamante de 500+ PO consumido, volta com
    1 PV e −4 em testes de d20, que diminui 1 a cada descanso longo.

### GitHub (referências de implementação)

| Repo | Estrelas | Licença | Última atividade | Cobertura | Notas |
|------|----------|---------|------------------|-----------|-------|
| [rapotekhin/dnd_llm](https://github.com/rapotekhin/dnd_llm) (`game/core/rules/harm.gd`) | 0 | nenhuma | 2026-11-06 | padrão | GDScript. Contador `{ok, fail}` por combatente, condição Inconsciente a 0 PV, dano massivo, falha por golpe a 0 PV. Confirma o desenho; **sem licença, não se copia código** |
| [brandonbrown215bb-boop/DND-Sandbox-Engine](https://github.com/brandonbrown215bb-boop/DND-Sandbox-Engine) | 0 | nenhuma | 2026-11-05 | baixa | GDScript; testes de regras em lote. Só referência de estrutura de testes |
| [topherhaynie/dnd-crawler](https://github.com/topherhaynie/dnd-crawler) | 0 | nenhuma | 2026-07-29 | baixa | GDScript; modelos de ficha de monstro. Sem relação direta |

### Registries

Não se aplica: o Godot não tem gerenciador de pacotes no projeto, e não existe biblioteca de regras de D&D 5e
para GDScript com licença permissiva.

## Decisões por Problema

### Problema 1: estado de morte do combatente (caído, estável, morto) e o ciclo do turno
**Opções:** adaptar do `dnd_llm` (sem licença, não pode); biblioteca (não existe); hand-rolled.
**Decisão: hand-rolled no `Combatant` e no `CombatManager`.**
**Justificativa:** o motor de combate é próprio, e a regra é curta e precisa (SRD p.17-18). O desenho segue o
padrão confirmado: contador de sucessos e falhas, flag de estável e de morto, condição `unconscious` aplicada a
0 PV e removida ao curar.

### Problema 2: estabilizar um aliado
**Decisão: hand-rolled.** Um comando novo de combate, "estabilizar" (a ação Ajudar do SRD), feito por um aliado
adjacente com teste de Medicina CD 10 via `DiceRoller` (`CharacterSheet.roll_skill_check`, que já existe).
**Poupar os Moribundos** (truque do SRD) entra como dado de magia se o passo 2 achar barato; senão, vira dívida.

### Problema 3: inimigos que finalizam caídos
**Decisão: dado nos monstros, mais a IA.** Um campo novo e opcional no monstro, `finishes_downed`, liga o
comportamento de "às vezes" atacar um caído adjacente (com chance, via `DiceRoller`). Começa ligado só no chefe
goblin (Garra-Rubra). Um critério por Inteligência foi descartado: o chefe goblin e o goblin comum têm a mesma
Inteligência.

### Problema 4: morte persistente e ressurreição
**Decisão: campo `dead` no `CharacterData`** (padrão `false`, com migração no salvamento).
- No combate, **Revivificar** passa a valer só para quem morreu há até 10 rodadas (1 minuto), e o diamante
  continua sendo exigido.
- Fora do combate, o morto não entra em combate nem segue o grupo, e o retrato fica marcado. A ressurreição é um
  **serviço pago** num ponto neutro da vila; o preço e o lugar ficam para o passo 2, sem contradizer o compêndio.

### Problema 5: herói morto com o grupo vivo
**Decisão a detalhar no passo 2.** O usuário respondeu "o grupo segue até revivê-lo". Pergunta técnica: quem
anda no mapa quando o líder está morto? Proposta: o primeiro companheiro vivo assume o sprite e o controle até a
ressurreição.

### Problema 6: derrota total
**Decisão: tela de derrota com "Carregar último salvamento"** (`SaveManager`), e "Voltar ao título" como
segunda opção. O fluxo atual, que apaga tudo, sai.

### Problema 7: mostrar o estado na tela
**Decisão: o mínimo legível nesta onda.**
- Marcadores de sucessos e falhas ao lado do nome na lista de iniciativa e no token.
- Mensagens no registro do combate.
- Retrato cinza para caído e com marca de morto nos retratos do grupo.
- O polimento visual fica para a onda 3.

## Riscos Identificados

- **Mudança de esquema do salvamento:** mitigação com campo opcional e padrão `false`, mais testes de
  salvamento antigo, no padrão do `QuestLog.history`.
- **75 usos de `is_up()` e `living()`:** mitigação mantendo a semântica "de pé" e criando um estado separado
  para caídos, sem mudar o significado de `is_up()`. Roda a suíte inteira.
- **Herói morto com o grupo vivo:** a troca de líder mexe na exploração (sprite, retrato, conversas).
  Mitigação: sub-fase própria no plano.
- **Equilíbrio:** com morte real e ressurreição cara, o Ato I (com cerca de 100 PO) pode ficar punitivo.
  Mitigação: preço da ressurreição calibrado no plano, mais Revivificar no combate.

## Dependências Externas

- Nenhuma nova. A regra vem do SRD 5.2.1 (CC BY 4.0, já atribuído nos créditos).

## Pontos Não-Resolvidos para o Plan

- Quem conduz o grupo no mapa quando o líder está morto.
- Preço e lugar da ressurreição paga (neutro em relação ao compêndio do mestre).
- Chance de um inimigo inteligente finalizar um caído (por exemplo, 50% quando há caído adjacente).
- Poupar os Moribundos entra nesta onda ou vira dívida.
- Interação com a Proteção contra a Morte (`death_ward`), que hoje deixa o alvo com 1 PV, e com o "fica com 1 PV"
  de outras características.

## Métrica de sucesso da onda

- **No combate:** um personagem a 0 PV rola testes contra a morte visíveis (no registro e nos marcadores), pode
  ser estabilizado (Medicina CD 10) ou curado, e morre com 3 falhas ou dano massivo, como no SRD.
- **Depois do combate:** um companheiro morto fica morto ao salvar e carregar, até a ressurreição.
- **Na derrota:** a derrota total oferece carregar o último salvamento, e a partida não se perde.
- **Testes e documentação:** testes determinísticos cobrem cada ramo da regra (10+, menos de 10, 1, 20, dano a 0
  PV, crítico, dano massivo, estabilizar, curar) e a suíte inteira passa no CI. A adaptação do "volta com 1 PV" sai
  do `RULES_POLICY`.

## Referências de Código a Estudar Antes do Plan

- [`scripts/combat/combat_manager.gd:959`](../../scripts/combat/combat_manager.gd) — `_advance_turn` (início do turno)
- [`scripts/combat/combat_manager.gd:1597`](../../scripts/combat/combat_manager.gd) — `_apply_damage`
- [`scripts/combat/combat_manager.gd:1746`](../../scripts/combat/combat_manager.gd) — `_choose_target` (IA)
- [`scripts/combat/combat_manager.gd:404`](../../scripts/combat/combat_manager.gd) — `apply_results_to_party`
- [`scripts/exploration/exploration_manager.gd:60`](../../scripts/exploration/exploration_manager.gd) — fluxo de derrota
- [`scripts/save/save_game.gd`](../../scripts/save/save_game.gd) — validação e migração

## Quadro de obras (lido em 2026-11-07)
- Ondas vivas lidas: **0** (`tasks/obras/` não existia). Cruzamento com lista ALTERA: **nenhum**.
- Branches remotos conferidos: todos são de trabalhos já mesclados; nenhum é onda viva.
- Migration: não se aplica (sem banco). O salvamento local muda de esquema, com migração.
- Branch desta onda: `onda/testes-contra-a-morte` (criado do `main` em `8b80d20` e publicado no GitHub).

---

## Status

- [x] Mínimo 3 refs externas documentadas (SRD 5.2.1 + 3 repositórios)
- [x] Decisão registrada para cada problema
- [x] Hand-rolled justificado
- [x] Padrões da codebase identificados
- [x] Riscos e dependências mapeados
- [ ] Revisado pelo humano
- [ ] Aprovado para próxima fase

aprovado: false
