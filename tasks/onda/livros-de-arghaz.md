---
onda: livros-de-arghaz
fase-metodologia: 4
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
Passo **4 (code)**. Fases 1 e 2 entregues (`b04a2fa`, `7c18c1a`); 312 testes verdes, nenhum id alterado.
🔴 **Teto de 2 fases atingido: aguardando a verificação manual do responsável** (roteiro abaixo).
Não posso começar a Fase 3 antes disso.

## Você valida (Fases 1 e 2)
1. **Abertura.** Onde: jogo → Novo jogo. Ação: leia o texto da criação de personagem. Tem que: dizer "Era do
   Despertar", sem ano e sem "Ione". Se falhar: copie a frase errada.
2. **Chefe da vila.** Onde: Vila de Ribeira. Ação: veja o objetivo no topo e converse no poço. Tem que: objetivo
   "Fale com a chefe da vila"; nome no diálogo "Chefe da vila"; nenhum "Ione". Se falhar: print do diálogo.
3. **Diário.** Onde: tecla J, depois de aceitar a missão. Ação: abra as Crônicas. Tem que: "Arghaz e a mana" e "Os
   kobolds e o Arauto" com o texto novo. Se falhar: o título da crônica errada.
4. **Missão da Amara.** Onde: Clareira. Ação: vença o goblin da ruína. Tem que: o aviso diz "Volte até Amara". Se
   falhar: o texto do aviso.
5. **Texto completo.** Onde: `tasks/onda/livros-de-arghaz-textos.md` (o sonho, o epílogo e as 6 crônicas, que só
   aparecem no fim do ato). Ação: leia. Tem que: soar fiel aos livros e sem invenção. Se falhar: o trecho e o que
   mudar.
6. **Resumo do cânone.** Onde: `docs/HISTORIA.md`. Ação: leia, principalmente "Perguntas em aberto para o mestre".
   Tem que: estar correto pelas fontes. Se falhar: o parágrafo.

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

## Handoff — livros-de-arghaz — passo-4, Fases 1 e 2 entregues → verificação manual

**Projeto:** jogo_rpg — `C:\Users\ovito\OneDrive\Desktop\jogo_rpg`
**Branch:** `onda/livros-de-arghaz` (publicado; commits b04a2fa e 7c18c1a).

**Decisão desta fase:** F1 texto do jogo fiel aos livros (crônicas, abertura, sonho, epílogo, diálogos, "Volte
até %s", chefe da vila sem nome); F2 HISTORIA.md como resumo do cânone (proposta 0.11 arquivada em docs/arquivo/).
Teste novo tests/story/test_canon.gd trava termos que contradizem os livros. 312 testes verdes, nenhum id alterado.

**Artefatos:** tasks/onda/livros-de-arghaz.md (painel, tabela de fontes, roteiro "Você valida"),
tasks/onda/livros-de-arghaz-textos.md (todo o texto novo para leitura).

**Ler antes de agir:**
1. tasks/onda/livros-de-arghaz.md — fases, roteiro de validação, dívida D-LA-01
2. tasks/specs/livros-de-arghaz.md — Fases 3 a 6 (peças do Ermo, posição salva, mapas, fechamento)

**Gotchas / decisões não-óbvias:**
- Fase 3: rodar o gerador de arte SEM mudança e conferir git status antes de criar peças.
- Fase 4 (CM-LA-01): exploration_map.gd também está na folha de testes-contra-a-morte.
- D-LA-01: Guia_do_Mestre_Arghaz.docx ainda cita Ione; regerar quando os nomes do mestre chegarem.

**Gate pendente:** 🔴 aguardando verificação manual — roteiro de 6 itens no feed.

**Próxima ação:**
/passo-4-code livros-de-arghaz   (Fase 3, depois da validação)
```
