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
Passo **4 (code)**. Fases 1-2 validadas (2026-11-20). Fases 3, 4 e 5 entregues (`f459e9c`, `b41cb03`, `334d063`);
323 testes verdes.
🔴 **Teto de 2 fases sem validação atingido (3 e 5): aguardando a verificação manual do responsável.**
Não posso começar a Fase 6 (fechamento) antes disso.

## Você valida (Fases 3 e 5 — o Ermo nos mapas)
1. **Bosque do Riacho.** Onde: da vila, siga para o Bosque. Ação: ande pela trilha do oeste até o acampamento. Tem
   que: a trilha virou estrada antiga (pedras com falhas e mudas nas rachaduras), com duas árvores ancestrais à beira,
   muralha e colunas caídas pela grama. Se falhar: print e o que estranhou.
2. **Andar sobre as pedras.** Onde: a mesma estrada. Ação: ande por cima do calçamento e das raízes. Tem que: passar
   livre; só o tronco das árvores e as ruínas bloqueiam. Se falhar: onde ficou preso.
3. **Clareira da Encruzilhada.** Onde: Clareira. Ação: ande pela estrada a oeste e veja o lago. Tem que: calçamento
   antigo na estrada, árvore ancestral na beira do lago, ruínas espalhadas; Amara, a ruína e a placa no mesmo lugar.
   Se falhar: print.
4. **Vila de Ribeira.** Onde: a praça do poço. Ação: olhe a praça. Tem que: pedras antigas na praça; casas, NPCs e
   placas iguais a antes. Se falhar: print.
5. **Save antigo.** Onde: Continuar (o seu save de antes). Ação: carregue. Tem que: carregar no lugar de sempre, sem
   ficar preso em árvore ou ruína. Se falhar: em que mapa e onde.

## As fases
| # | Fase | Estado |
|---|---|---|
| 1 | Texto do jogo (crônicas, abertura, cenas, epílogo, diálogos, "Volte até") | ✅ `b04a2fa` · validado pelo responsável em 2026-11-20 ("aprovado") |
| 2 | Documentos do cânone (`HISTORIA.md` reescrito, perguntas ao mestre) | ✅ `7c18c1a` · validado pelo responsável em 2026-11-20 ("aprovado") |
| 3 | Peças do Ermo no gerador (sem tocar mapa) | ✅ código e testes; gerador conferido determinístico (16 arquivos idênticos) e atlas alterado só nas casas (6..9, 0); visual conferido contra o modelo; 🔴 você vê nos mapas na Fase 5 |
| 4 | Posição salva segura ao carregar (CM-LA-01) | ✅ código e testes (4 casos + caminho real de volta do combate); sem verificação manual (só age se a posição estiver bloqueada) |
| 5 | Ermo nos mapas (Bosque, Clareira; vila só calçamento) | ✅ código e testes (preservação dos objetos antigos, zonas protegidas, camada sem colisão); 🔴 aguardando verificação manual |
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

## Handoff — livros-de-arghaz — passo-4, Fases 3-5 entregues → verificação manual

**Projeto:** jogo_rpg — `C:\Users\ovito\OneDrive\Desktop\jogo_rpg`
**Branch:** `onda/livros-de-arghaz` (publicado; f459e9c, b41cb03, 334d063).

**Decisão desta fase:** F3 peças do Ermo no gerador (árvore ancestral, jovem, muda, muralha, coluna, 4 ladrilhos de
calçamento nas casas livres (6..9,0)). F4 CM-LA-01: safe_spawn/is_spot_blocked em exploration_map.gd (geometria,
anéis de 16 px, máx. 8; inválido/fora do mapa → entrada). F5 Ermo nos mapas: camada Detail sem colisão, RNG próprio
(_ermo) depois do espalhamento antigo, árvores ancestrais à beira da estrada antiga, 1 em 3 árvores do miolo vira
jovem. 323 testes verdes; objetos antigos conferidos contra tests/fixtures/props_before_ermo.json.

**Ler antes de agir:**
1. tasks/onda/livros-de-arghaz.md — roteiro "Você valida", fases, dívida D-LA-01
2. tasks/specs/livros-de-arghaz.md — Fase 6 (fechamento) e o grep de métrica
3. tasks/security/livros-de-arghaz.md — CM-LA-03 (pacote Web sem docs/) fica para a Fase 6

**Gotchas / decisões não-óbvias:**
- Regerar cenas muda todos os unique_id (Godot 4.7); tirando isso, o gerador reproduz as cenas versionadas.
- village_props.tscn não muda: depois de regerar a vila, restaurar do git (só unique_id).
- Árvore ancestral: espaçamento 2 e proteção 3 casas (a floresta é densa; o teste de zonas confere).

**Gate pendente:** 🔴 aguardando verificação manual — roteiro de 5 itens no feed.

**Próxima ação:**
/passo-4-code livros-de-arghaz   (Fase 6, depois da validação)
```
