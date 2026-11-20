---
onda: livros-de-arghaz
fase-metodologia: 4
estado: FECHADA
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
**Passo 4 FECHADO** (2026-11-20). As 6 fases foram entregues, e as Fases 1, 2, 3 e 5 foram validadas pelo
responsável ("aprovado"). A Fase 4 não tem verificação manual própria; o item 5 do roteiro do Ermo (save antigo)
cobriu ela. 323 testes verdes, exportação Web OK.
Próximo: `/passo-5-review livros-de-arghaz`.

## Mapa CM → código
| CM | Onde | Prova |
|---|---|---|
| CM-LA-01 posição salva segura | `scripts/exploration/exploration_map.gd:48` (ramo de volta) e `:592` (`safe_spawn`) | `tests/exploration/test_safe_spawn.gd` (sobre objeto, livre, fora do mapa, NaN, infinito, volta de combate) |
| CM-LA-02 sem BBCode acidental | `tests/story/test_canon.gd:90` | O teste varre lore, story, dialogues e quests |
| CM-LA-03 pacote Web sem docs/ | `export_presets.cfg:10-11` (sem mudança) | Exportação de 2026-11-20: 0 ocorrências de `docs/` ou `.docx` no `index.pck` |

## Releitura do spec (B.2)
- As Fases 1 a 6 batem com o spec. Ids intactos (nenhuma linha `"id":` alterada). `village_props.tscn` não mudou.
- O grep de métrica virou teste permanente (`test_canon.gd`), mais forte que o grep de uma vez.
- Divergência aceita: o spec pedia uma sonda automática carregando um save de antes da onda. Ela foi coberta pelo
  teste do caminho real de volta (`test_returning_onto_a_prop_is_corrected_on_load`) e pela validação manual do
  responsável com o save dele (item 5 do roteiro). Não virou dívida.
- Fora do spec, decidido pelo responsável no caminho: Garra-Rubra fica (está no compêndio).

## As fases
| # | Fase | Estado |
|---|---|---|
| 1 | Texto do jogo (crônicas, abertura, cenas, epílogo, diálogos, "Volte até") | ✅ `b04a2fa` · validado pelo responsável em 2026-11-20 ("aprovado") |
| 2 | Documentos do cânone (`HISTORIA.md` reescrito, perguntas ao mestre) | ✅ `7c18c1a` · validado pelo responsável em 2026-11-20 ("aprovado") |
| 3 | Peças do Ermo no gerador (sem tocar mapa) | ✅ `f459e9c` · validado pelo responsável em 2026-11-20 ("aprovado") |
| 4 | Posição salva segura ao carregar (CM-LA-01) | ✅ código e testes (4 casos + caminho real de volta do combate); sem verificação manual (só age se a posição estiver bloqueada) |
| 5 | Ermo nos mapas (Bosque, Clareira; vila só calçamento) | ✅ `334d063` · validado pelo responsável em 2026-11-20 ("aprovado") |
| 6 | Fechamento (ROADMAP, CHANGELOG, CLAUDE.md; CM-LA-03 na exportação) | ✅ exportação Web conferida; docs atualizados |

## Dívidas desta onda
| ID | O quê | Motivo | Plano |
|---|---|---|---|
| D-LA-01 | `docs/Guia_do_Mestre_Arghaz.docx` ainda cita Ione e a Floresta Sussurrante | O gerador do `.docx` ficou num scratchpad apagado; refazer leva mais que minutos | Regerar a partir de `docs/GUIA_DO_MESTRE.md` (já atualizado) quando o mestre mandar os nomes, para gerar uma vez só |

## Tabela de fontes do texto novo (Fase 1)
| Texto | O que afirma | Fonte |
|---|---|---|
| Crônica "Arghaz e a mana" | Superterra colossal, um continente, origem natural; vida nascida na presença da mana; magia começou como biologia | Livro II, prólogo e caps. 1-2 |
| Crônica "Os kobolds e o Arauto" | Kobolds, primeiro povo pensante; Arauto manipula mana conscientemente; manipular não é criar; adorado na Cidade dos Três como figura real | Livro II, cap. 4; Livro I ("Verdade e Memória") |
| Crônica "A Era dos Colossos" | Mana abundante, corpos colossais, dragões ancestrais quase imortais; biocriação e redes; arqueologia vertical | Livro II, cap. 6; Livro I (eras e ruínas) |
| Crônica "A Rarefação e as Garras" | Rarefação após a Era Amaldiçoada; dragões disputaram reservatórios; Garras do Arauto reaparecem e são disputadas | Livro II, cap. 7; compêndio §9 |
| Crônica "Vermeth, a Brasa Coroada" | Adulta, Linhagem Vermelha, desperta; defende a conquista; busca relíquias do Arauto; Wyrmgard não citada; cor não determina moral | Compêndio §7; Livro I |
| Crônica "A Era do Despertar" | Povo Humanoide Ancestral; anões, golias e gigantes por biocriação; Era do Despertar; o Ermo | Livro I; compêndio §1 |
| Abertura (`INTRO_TEXT`) | Era do Despertar, sem ano; reabertura das estradas | Livro I; compêndio §1 e §9 |
| Sonho | Voz distante reconhece uma Garra do Arauto e quer buscá-la (sem posse, sem lugar) | Compêndio §7 e §12 (D3) |
| Epílogo | Algo desperto e distante sabe que a Garra acordou | Compêndio §7 |
| Chefe da vila, floresta de Ribeira, Estalagem de Ribeira, falas de Ignis, Lyra e Doran | Sem nome próprio inventado nem lore sem fonte | Decisões D2 e D4 |

## 📋 Handoff

```
Tarefa: livros-de-arghaz · Crônicas de Arghaz

## Handoff — livros-de-arghaz — passo-4 FECHADO → passo-5 (revisão)

**Projeto:** jogo_rpg — `C:\Users\ovito\OneDrive\Desktop\jogo_rpg`
**Branch:** `onda/livros-de-arghaz` (publicado). Não há PR aberto da onda (o #29 era só do passo 1 e foi mesclado).

**Decisão desta fase:** 6 fases entregues, e as Fases 1, 2, 3 e 5 foram validadas pelo responsável. Texto fiel aos
livros (+ teste test_canon); HISTORIA.md como resumo do cânone; peças do Ermo no gerador; safe_spawn (CM-LA-01); Ermo
nos mapas (camada Detail, RNG _ermo, objetos antigos preservados); exportação Web sem docs/ (CM-LA-03). 323 testes
verdes.

**Ler antes de agir:**
1. tasks/onda/livros-de-arghaz.md — Mapa CM → código, releitura do spec, dívida D-LA-01
2. tasks/security/livros-de-arghaz.md — plano de teste de segurança para o review
3. git diff main...onda/livros-de-arghaz — o que revisar (as cenas regeradas têm ruído de unique_id)

**Gotchas / decisões não-óbvias:**
- Diff das cenas *_props/*_terrain é grande por causa do unique_id do Godot 4.7; o conteúdo real é a camada Detail e
  as peças novas.
- D-LA-01 (Guia_do_Mestre_Arghaz.docx desatualizado) fica para quando os nomes do mestre chegarem.
- No fechamento (passo 5): apagar tasks/obras/livros-de-arghaz.md, marcar ✅ no ROADMAP, merge para o main.

**Gate pendente:** não há verificação manual nesta rodada (as fases visuais já foram validadas).

**Próxima ação:**
/passo-5-review livros-de-arghaz
```
