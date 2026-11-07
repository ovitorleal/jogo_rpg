---
feature: livros-de-arghaz
onda: livros-de-arghaz
fase: research
data: 2026-11-07
projeto: As Crônicas de Arghaz
aprovado: true
aprovado_por: Vitor Leal
aprovado_em: 2026-11-07
aprovacao: "registrada pelo Claude a pedido do responsável, que tentou marcar e não conseguiu (\"nao estou conseguindo marcar\")"
llm-routing:
  proxima-fase: passo-2-plan
  modelo: claude-sonnet-5-5
  thinking: true
  effort: medio
  justificativa: "Pouco código e nenhum esquema novo, mas reescrita de texto canônico com fidelidade às fontes e uma peça visual que precisa de modelo aprovado antes; o risco é de conteúdo e de gosto, não técnico."
---

# Research — Livros de Arghaz

## Contexto e Motivação

O mestre do RPG entregou dois livros revisados:
- **Livro I, "A Identidade de Arghaz":** o mundo, o tempo, os povos, verdade e memória.
- **Livro II, "A Natureza de Arghaz":** o corpo do mundo, a mana, a rarefação, o Ermo e as fronteiras planares.

Ele pediu que o jogo mude nomes e histórias iniciais para seguir os livros fielmente, que o visual da natureza siga o
que eles descrevem, e que os livros entrem nos arquivos do jogo.

A história atual do jogo (Fase 9, 0.11.0) veio de um arquivo de lore anterior (`As Crônicas de Arghaz.md`, na raiz).
Ela inventou eras e eventos que os livros agora contradizem: a "Era da Criação", a "Guerra das Escamas", o "Silêncio
dos dragões" e a "Era dos Homens, ano 1.214". O `docs/HISTORIA.md` já registrava que tudo isso era provisório.

## Fase 0 — Compreensão

### Restate
Corrigir todo texto do jogo que contradiz os Livros I e II (ou o compêndio, onde os livros não falam). Tirar os nomes
próprios que nenhuma fonte sustenta. Trocar a natureza dos mapas pelo **Ermo** dos livros: vida crescida sobre
estradas e ruínas antigas, com árvores ancestrais entre árvores novas menores. Guardar os livros em `docs/livros/`.

### Pressupostos
- `[CONFIRMADO]` O compêndio da Sexta Era vale como fonte onde os livros não falam; em conflito, o livro vence.
- `[CONFIRMADO]` Onde nenhuma fonte dá nome, sai o nome próprio e entra uma descrição. Companheiros mantêm o nome.
- `[CONFIRMADO]` "Visual da natureza" = cenário do mapa (terreno, árvores, raízes, ruínas). Personagens não mudam.
- `[CONFIRMADO]` Livros em `docs/livros/` (originais + transcrição), sem leitura dentro do jogo.
- `[ASSUMIDO ÓBVIO]` Mecânica, classes, missões (estrutura), encontros e recompensas continuam iguais.
- `[ASSUMIDO ÓBVIO]` Ids (`quest.*`, `dialogue.*`, `item.*`, `story.*`, `lore.*`) não mudam: o salvamento guarda ids.

### Gaps respondidos pelo usuário (2026-11-07)
| Pergunta | Resposta |
|---|---|
| De onde vêm os nomes locais que os livros não dão? | **Tirar nomes próprios** (descrição no lugar); companheiros mantêm nome |
| O compêndio ainda vale? | **Livros + compêndio** (livros mandam, compêndio completa) |
| Até onde vai o visual? | **Cenário do mapa**, com modelo aprovado antes de aplicar |
| Onde entram os livros? | **`docs/livros/`** (docx + .md), sem leitura no jogo |

⚠️ **Consequência que o responsável precisa ver:** com o compêndio valendo, **quase todos os nomes do Ato I têm
fonte** e ficam. O compêndio (seção 8, "Rotas, assentamentos e fronteiras") nomeia Vila de Ribeira, Clareira da
Encruzilhada, Bosque do Riacho, Amara, Garra-Rubra, Garra Vermelha, Vessa e Montes de Ferro, e a seção 7 nomeia
Vermeth. Saem só **Ione** e os nomes de eras e eventos inventados. O que muda de verdade é a **história**, não a lista
de nomes. Se o mestre queria trocar também os nomes que o compêndio dele mesmo usa, isso precisa vir dele.

### Anti-escopo
- Missões novas, Ato II, cidades do compêndio (Althelas, Kharzan...): o mestre escreve.
- Sprites, retratos e animação de personagens (reprovados duas vezes; fora daqui).
- Regras de combate e morte (onda `testes-contra-a-morte`).
- Telas de título, viagem e combate (o responsável escolheu só o cenário do mapa).
- Leitura dos livros dentro do jogo.

### Pre-mortem (erros de ondas anteriores para não repetir)
1. **Arte de personagem reprovada** ("Está PÉSSIMO", "Não ficou bom"): esta onda não toca personagem.
2. **Mudar o visual sem aprovação prévia:** o cenário novo só entra depois de um modelo (imagem real gerada pelo
   pipeline, não descrição) aprovado pelo responsável.
3. **Inventar cânone:** o Livro II proíbe "criar números, mecanismos metafísicos, taxonomias rígidas ou explicações
   causais que as fontes não estabelecem" (Dossiê Editorial). Vale para nós: nada de "três vezes maior", "Segunda
   Corrente" ou ano 1.214.
4. **Quebrar o save de quem já joga** ([[engenharia-reversa-antes-de-alterar]]): trocar id de missão, diálogo ou nó
   prende o jogador. Só texto muda.
5. **`build_overworld.gd --force` apaga edições do editor** (CLAUDE.md): regenerar mapa só com o layout conferido.

## Estado Atual da Codebase

| Onde | O que tem hoje | Fonte que sustenta |
|---|---|---|
| `data/lore/chronicles.json` (6 crônicas) | "Arghaz e a mana" (3× maior, "Segunda Corrente"); "Os kobolds e o Arauto"; "As linhagens e a Era da Criação"; "O Silêncio e as Garras" (Guerra das Escamas, dragões sumiram); "Vermeth, a Brasa que Dorme" (adormecida sob as montanhas do leste); "A Era dos Homens" (humanos surgiram do nada, ano 1.214) | Só a 2ª bate com o Livro II cap. 4. As outras contradizem os livros |
| `data/story/act1.json` | Cena "A Garra Vermelha" (oferendas, garra que "cresceu como osso") e "O sonho de fogo" (Vermeth sob a montanha, "terminaremos o que meu pai começou") + falas dos 6 companheiros | A Garra existe no compêndio ("Garras do Arauto"); o sonho contradiz Vermeth ativa em Wyrmgard |
| `data/quests/main_quest.json` | `giver: "Ione"`, descrição com Ione, epílogo "sob as montanhas do leste, algo imenso se vira no sono" | Ione sem fonte; epílogo contradiz o compêndio |
| `data/dialogues/ione.json` | Chefe da vila; "Garras do Arauto, de antes do Silêncio dos dragões"; "que os deuses guiem" | "Silêncio" sem fonte; deuses aceitável (Livro I: povos juram conhecer deuses) |
| `data/dialogues/companions.json`, `data/companions/companions.json` | Doran "anão ferreiro e sacerdote de Ribeira"; Ignis "meu avô era um dragão vermelho"; Lyra elfa da Floresta Sussurrante | Ver "Conflitos que ficam com o mestre" |
| `scripts/ui/character_creation.gd:7` | `INTRO_TEXT`: "ano 1.214 da Era dos Homens. Mil anos atrás os dragões silenciaram... Ione" | Contradiz Livro I (era atual é a do Despertar) |
| `scripts/exploration/exploration_map.gd:500` | Objetivo "Fale com Ione, a chefe da vila, perto do poço de Ribeira" | Ione sem fonte |
| `docs/HISTORIA.md` | Seis eras inventadas (Criação, Homens...), campanha em 3 atos com Vermeth adormecida | Todo marcado "proposta"; os livros substituem |
| Cenário | `tools/art/generate_environment.gd` (510 linhas) pinta tiles 16 px e props (árvore, pinheiro, arbusto, pedra, casas, poço, fogueira, placa) com a paleta da `docs/ART_BIBLE.md`; `tools/art/build_overworld.gd` monta `village`, `forest_brook`, `test_map` | Nada de ruína, estrada antiga ou árvore ancestral: é uma floresta "primordial" genérica, o oposto do Ermo |

### O que os livros e o compêndio estabelecem (o que o jogo precisa refletir)
- **Era atual: Era do Despertar**, a Sexta Era (Livro I; compêndio §1). Antes: Era Amaldiçoada (colapso da mana) e
  Era do Esquecimento (elites élficas reescreveram crônicas e mapas). Não há cronologia absoluta: "As Seis Eras são
  mais importantes do que datas" (Livro I) ⇒ **sem ano numérico**.
- **Mana é natureza**, a vida nasceu na presença dela, não por ela (Livro II, cap. 2). Depois da Era Amaldiçoada a
  mana **rareou**, sem sumir: refúgios, reservatórios e cicatrizes (caps. 7-8).
- **Kobolds, o primeiro povo pensante**; numa ninhada nasceu o **Arauto**, o primeiro a manipular mana
  conscientemente (Livro II, cap. 4). Na Cidade dos Três, Arauto, Grande Mãe e Carrasco são adorados como deuses,
  mas foram figuras reais (Livro I).
- **Humanos não "surgiram do nada":** humanos, goblinoides, gnomos e halflings descendem do **Povo Humanoide
  Ancestral**; anões, golias e gigantes compartilham ancestralidade derivada de biocriação (Livro I).
  ⇒ Goblins também não são "ferramentas largadas".
- **Dragões não sumiram:** disputaram reservatórios e aceleraram a própria extinção (Livro II, cap. 7). Em Wyrmgard,
  escondida, dorme o **último Primordial**, e cinco adultos governam; **Vermeth, a Brasa Coroada**, é ativa e
  "busca relíquias ligadas ao Arauto" (compêndio §7). Cor das escamas não define moral (Livro I).
- **O Ermo:** "Florestas, montanhas e vida cresceram sobre estradas, fortalezas, cidades e estruturas esquecidas"; "há
  florestas mais jovens que as pedras sob suas raízes"; arqueologia vertical (élfico → orc → dracônico → cavernas)
  (Livro I). Na rarefação, "uma floresta conserva por algum tempo árvores ancestrais, mas as novas não ocupam o mesmo
  teto" (Livro II, cap. 7). Epílogo do Livro II: semente na rachadura de uma estrada antiga, raiz erguendo a pedra.

## Estado atual e impacto (engenharia reversa)

**Consumidores reais (grep de 2026-11-07):**
- "Ione" aparece em 22 arquivos: dados (`companions.json`, `amara.json`, `companions.json` de diálogos, `ione.json`,
  `main_quest.json`), cenas (`npc_ione.tscn`, `village.tscn` nó `Objects/Ione`), código (`exploration_map.gd:500`,
  `character_creation.gd:7`, `generate_characters.gd` com `OUT_IONE`), testes (`test_vertical_slice.gd` 60-62, 99-101,
  162; `test_story.gd` 3, 139-141; `test_quest_history.gd` 43; `test_companions.gd` 154) e docs.
- O nome exibido do NPC vem do diálogo (`speaker`), não do nó. `test_vertical_slice.gd:62` confere
  `get_speaker_name() == "Ione"` e `:60` confere o texto do objetivo ⇒ **esses testes mudam de expectativa**.
- "Era dos Homens"/"1.214": `chronicles.json`, `character_creation.gd`, `HISTORIA.md`, `CHANGELOG.md` (histórico, não
  se reescreve).

**Estados preexistentes do dado (saves que já existem):**
- O salvamento guarda **ids**: `QuestLog` (ids de missão e objetivo), `once_events` (`story.*`), crônicas
  desbloqueadas (`lore.*`), inventário (`item.red_claw`), estado de diálogo por id. Nome exibido vem do registro em
  tempo de execução (`save_game.gd:52-57` lê `name` do registro).
  ⇒ **Trocar só texto não quebra save nenhum.** Trocar um id quebraria: por isso **ids ficam**, inclusive
  `dialogue.ione`, `npc_ione.tscn` e o nó `Objects/Ione` (nomes internos, o jogador não vê).
- Crônica já desbloqueada num save antigo passa a mostrar o texto novo: é o efeito desejado.
- Posição salva do jogador no mapa: se um prop novo (árvore ancestral, bloco de ruína) cair em cima dessa posição, o
  jogador pode nascer dentro de uma colisão. ⇒ O plano precisa manter livres as áreas de chegada (`Entrances/`) e os
  caminhos, ou conferir a posição ao carregar.

**Três populações:**
| População | O que sente |
|---|---|
| (a) Jogador novo | Abertura e crônicas novas; chefe da vila sem nome próprio; floresta do Ermo |
| (b) Jogador com save no meio do Ato I | Mesmo progresso, textos novos; crônicas já lidas mudam de texto; cenário muda debaixo dele (risco de colisão na posição salva) |
| (c) Borda: save parado ao lado de onde entra uma ruína, ou com a cena do sonho já vista | Colisão: tratar no plano. Sonho já visto não repete (`once_events`), sem efeito |

## Pesquisa Externa

### Fonte primária
- Os próprios livros e o compêndio, agora em `docs/livros/` (originais + transcrição). Não há biblioteca nem repositório
  que resolva "reescrever texto canônico"; a referência é o texto do mestre.

### Referências visuais (padrão de mercado, sem copiar)
- O motivo "floresta sobre ruínas" é recorrente em RPGs de pixel art (pedras de calçamento quebradas sob raízes, colunas
  caídas com musgo, árvore muito maior que as vizinhas como marco). A `docs/ART_BIBLE.md` proíbe copiar cenários e
  paletas de jogos existentes ⇒ as peças serão **pintadas pelo nosso pipeline** (`generate_environment.gd`, mesma
  técnica de 16 px, contorno `#1a1020`, sombra roxa), com a forma ditada pelo texto dos livros.

### Registries
- Não se aplica: nenhuma dependência nova.

## Decisões por Problema

### Problema 1: livros no repositório
**Feito nesta fase** (o scratchpad é temporário e a próxima sessão precisa das fontes): `docs/livros/` com os dois
`.docx` revisados, o compêndio (marcado rascunho) e as transcrições `.md`, mais `LEIA-ME.md` com a hierarquia
**livros > compêndio > HISTORIA.md**.

### Problema 2: crônicas do diário
**Reescrever as 6** (ids e gatilhos de desbloqueio iguais), cada uma presa a uma passagem citável:
1. `lore.arghaz` → superterra natural, mana como natureza, vida nascida **na presença** da mana (Livro II caps. 1-2).
2. `lore.arauto` → já fiel; ajuste fino ao texto do Livro II cap. 4 ("manipular", não "controlar"; sem "Primeiro
   Dragão" se nenhuma fonte disser isso ⇒ conferir no plano).
3. `lore.dragons` → vira as Eras e a abundância: Era dos Colossos, longevidade quase imortal dos dragões ancestrais,
   arqueologia vertical (Livro I; Livro II cap. 6). Some a "Era da Criação".
4. `lore.silence` → vira a Rarefação: depois da Era Amaldiçoada a mana rareou, dragões disputaram reservatórios
   (Livro II cap. 7). Some o "Silêncio".
5. `lore.vermeth` → **Vermeth, a Brasa Coroada**: adulta da Linhagem Vermelha, ativa, busca relíquias do Arauto
   (compêndio §7). Wyrmgard é segredo do mundo, então a crônica fala do que o jogador **pode saber**, sem revelar a
   cidade (decisão do plano).
6. `lore.humans` → vira os povos e o Despertar: Povo Humanoide Ancestral, a Era do Despertar como reabertura das
   estradas (Livro I; compêndio §9). Some a "Era dos Homens".
Os títulos das crônicas também mudam onde citam eventos inventados.

### Problema 3: abertura, missão principal e cenas
- `INTRO_TEXT` sem ano: "Arghaz, Era do Despertar..." com a reabertura das estradas; a chefe da vila sem nome.
- Epílogo do Ato I e cena do sonho: Vermeth **acordada e distante**, procurando a Garra; sai "sob as montanhas do
  leste" e "o que meu pai começou".
- Cena "A Garra Vermelha": mantém (o compêndio sustenta as Garras do Arauto); ajusta só o que for invenção causal.

### Problema 4: Ione
Nome exibido vira **"Chefe da vila"** (speaker, `giver`, objetivo, abertura, falas que a citam). Ids e nomes internos
ficam. Testes que conferem "Ione" passam a conferir "chefe da vila".

### Problema 5: o Ermo no cenário
Hand-rolled no pipeline existente, **com modelo antes**:
- Peças novas: **árvore ancestral** (2-3× a árvore atual, tronco largo, raízes expostas), **calçamento antigo** (tiles
  de estrada de pedra rachada sob grama e raízes), **ruína** (bloco/coluna caída com musgo, base de muralha) e
  **broto/árvore jovem** menor, para o contraste "as novas não ocupam o mesmo teto".
- Onde: `forest_brook` (Bosque do Riacho, que o compêndio liga a "relíquias e linhagens antigas") e a Clareira da
  Encruzilhada ("a ruína próxima... entradas laterais de complexos antigos", compêndio §8). A vila ganha só um traço
  (casas sobre fundação de pedra antiga), pois é assentamento vivo.
- Passo 4 começa por **um modelo**: captura real do mapa com as peças novas, para o responsável aprovar antes de
  espalhar.

## Riscos Identificados
| Risco | Mitigação |
|---|---|
| Reescrita "fiel" que ainda inventa detalhe | Cada texto novo cita a passagem-fonte no plano; o review confere frase por frase |
| Responsável não gostar do visual (histórico de reprovação) | Modelo antes de aplicar; só cenário; reversão fácil por ser gerado por script |
| Prop novo sobre a posição salva do jogador | Manter áreas de chegada e caminhos livres; conferir no plano se o carregamento corrige a posição |
| `--force` no gerador apagar edições do editor | Conferir o diff das cenas antes de regenerar |
| Colisão com `testes-contra-a-morte` | Não tocar `tests/party/test_companions.gd` nem `data/monsters/` |

## Dependências Externas
- Nenhuma. As respostas do mestre às 13 perguntas da Sexta Era podem mudar textos depois, sem bloquear a onda.

## Pontos Não-Resolvidos para o Plan
1. **Conflitos que ficam com o mestre** (não decidir sozinho, listar no plano):
   - Doran é **anão vivendo abertamente** em Ribeira, mas os anões vivem em segredo em Thalduim e o bastião compra por
     intermediários (Livro I; compêndio §4). Já está entre as 13 perguntas.
   - Ignis, **draconato** fora de Wyrmgard ("a maioria" vive lá: exceção possível) e "meu avô era um dragão vermelho".
   - Lyra, **elfa** fora de Althelas ("quase toda a população élfica": exceção possível).
2. A crônica do Arauto pode dizer "Primeiro Dragão"? Conferir no compêndio antes de escrever.
3. Vermeth: quanto o jogador sabe de Wyrmgard no Ato I (segredo do mundo).
4. Tamanho e quantidade das peças do Ermo e onde cada uma entra (layout).
5. `docs/HISTORIA.md`: reescrever como resumo do cânone dos livros ou arquivar a proposta antiga.

## Métrica de sucesso da onda
- Nenhum texto exibido ao jogador contradiz os Livros I e II ou o compêndio (conferência por grep de "Era dos Homens",
  "1.214", "Silêncio", "Era da Criação", "Brasa que Dorme", "Ione" no conteúdo do jogo = zero).
- Todos os testes verdes, com as expectativas de texto atualizadas.
- Save antigo do meio do Ato I carrega e continua.
- Modelo do Ermo aprovado pelo responsável antes de aplicar.

## Referências de Código a Estudar Antes do Plan
- `tools/art/generate_environment.gd` (`_tree`, `_rock`, `_transition_tile`) e `tools/art/build_overworld.gd` (layouts).
- `scripts/story/story_director.gd` e `data/story/act1.json` (gatilhos e falas).
- `scripts/save/save_game.gd` (o que é salvo e como a posição do jogador volta).
- `tests/quests/test_vertical_slice.gd`, `tests/story/test_story.gd`.

## Quadro de obras (lido em 2026-11-07)
- Ondas vivas lidas: **1** (`testes-contra-a-morte`, passo 1). Cruzamento com a lista ALTERA dela: **nenhum** (ela
  altera o esquema do salvamento; esta não).
- Arquivo em comum declarado: `tests/party/test_companions.gd` (esta onda decidiu **não** tocar).
- Disco conferido: `git diff --name-only main...onda/testes-contra-a-morte` vazio (o passo 1 dela já está no `main`
  via PR #28; o código dela ainda não existe).
- ⚠️ O PR #28 (só documentação do passo 1) foi mesclado no `main`, apesar do aviso "não mesclar até o passo 5". Nenhum
  efeito no jogo; registrado para o responsável.
- Migration: não se aplica (sem banco; o salvamento não muda de esquema).
- Branch desta onda: `onda/livros-de-arghaz` (criado do `main` em `fbf94fd` e publicado no GitHub).

---

## Status

- [x] Fontes primárias lidas por inteiro (Livro I, Livro II, compêndio)
- [x] Decisão registrada para cada problema
- [x] Hand-rolled justificado (texto canônico e arte no pipeline próprio)
- [x] Padrões da codebase identificados
- [x] Riscos, estados preexistentes e três populações mapeados
- [x] Revisado pelo humano
- [x] Aprovado para próxima fase (Vitor Leal, 2026-11-07)

aprovado: true
