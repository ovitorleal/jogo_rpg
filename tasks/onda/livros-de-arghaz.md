---
onda: livros-de-arghaz
fase-metodologia: 3
estado: EM-CODIGO
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
- Threat model **aprovado** pelo responsável (2026-11-20).

Próximo: `/passo-4-code livros-de-arghaz`.

## As fases
| # | Fase | Estado |
|---|---|---|
| 1 | Texto do jogo (crônicas, abertura, cenas, epílogo, diálogos, "Volte até") | ✅ código e testes; 🔴 aguardando verificação manual |
| 2 | Documentos do cânone (`HISTORIA.md` reescrito, perguntas ao mestre) | ✅ escrito; 🔴 aguardando sua leitura |
| 3 | Peças do Ermo no gerador (sem tocar mapa) | ⬜ |
| 4 | Posição salva segura ao carregar (CM-LA-01) | ⬜ |
| 5 | Ermo nos mapas (Bosque, Clareira; vila só calçamento) | ⬜ |
| 6 | Fechamento (ROADMAP, CHANGELOG, CLAUDE.md; CM-LA-03 na exportação) | ⬜ |

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

## Handoff — livros-de-arghaz — passo-3 concluído → passo-4

**Projeto:** jogo_rpg — `C:\Users\ovito\OneDrive\Desktop\jogo_rpg`
**Branch:** `onda/livros-de-arghaz` (publicado; atualizado com o main em 2026-11-20).

**Decisão desta fase:** risco geral baixo; 3 contramedidas. Prioridade: CM-LA-01 (posição salva: só valor finito,
fora do mapa vai para Entrances/*, busca com raio máximo; posição livre = comportamento de hoje), na Fase 4.
CM-LA-02 (sem colchetes BBCode acidentais no texto novo) e CM-LA-03 (pacote Web sem docs/). RR-LA-01: livros do
mestre públicos no GitHub, risco aceito pelo responsável ("Manter público").

**Artefato gerado:** `tasks/security/livros-de-arghaz.md` (aprovado: true, Vitor Leal, 2026-11-20)

**Ler antes de agir:**
1. `tasks/specs/livros-de-arghaz.md` — as 6 fases, a suposição mais arriscada de cada uma, o grep de métrica
2. `tasks/security/livros-de-arghaz.md` — CM-LA-01..03 viram requisitos; plano de teste para o passo 5
3. `docs/livros/` — a fonte de cada frase nova da Fase 1

**Gotchas / decisões não-óbvias:**
- Ids nunca mudam (saves guardam ids); nomes dos companheiros esperam o arquivo do mestre.
- `.docx` do mestre inspecionados: sem macros, embutidos ou links externos.
- `exploration_map.gd` também está na folha de testes-contra-a-morte: reler folha e disco antes da Fase 4.
- llm-routing: Haiku por padrão; Sonnet nas Fases 4 e 5.

**Gate pendente:** nenhum, pronto para seguir.

**Próxima ação:**
/passo-4-code livros-de-arghaz
```
