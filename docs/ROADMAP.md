# Roadmap

| Fase | Descrição | Estado |
|---|---|---|
| 0 | Fundação técnica | Concluída (2026-10-23) |
| 1 | Primeiro mapa | Concluída (2026-10-23) |
| 2 | Modelo de personagens | Concluída (2026-10-23) |
| 3 | Combate | Concluída (2026-10-24) |
| 4 | Viagens e encontros | Concluída (2026-10-24) |
| 5 | Progressão e conteúdo | Concluída (2026-10-24) |
| 6 | Salvamento e integração | Concluída (2026-10-24) |
| 6.5 | Magias e efeitos visuais | Concluída (2026-10-24) |
| 6.6 | Características de classe (1–20), subclasses, antecedentes e talentos | Concluída (2026-10-25) |
| 7 | Vertical slice | Concluída (2026-10-25) |
| 8 | Publicação | Concluída (2026-10-27) — preparação; site no ar após a ativação do Pages |
| Extra | Companheiros recrutáveis | Concluída (2026-10-27) — 0.9.0 |
| Extra | Nome e logo: As Crônicas de Arghaz | Concluída (2026-10-27) — 0.10.0 |
| 9 | A história de Arghaz no jogo (Ato I) | Concluída (2026-10-29) — 0.11.0 |
| Extra | Subida de nível e retratos do grupo | Concluída (2026-10-29) — 0.12.0 |

Extras pós-Fase 5: aparência modular das espécies (0.5.1) e arte dos personagens em alta resolução (0.5.2), 2026-10-24 — ver abaixo.

## Fase 6.6 — características completas (pedido do responsável)

Escopo escolhido: níveis 1 a 20 das 12 classes, as 12 subclasses do SRD, os 4 antecedentes e os 17 talentos.
Fonte: SRD 5.2.1 (PDF oficial, CC BY 4.0) lido localmente; descrições resumidas com texto próprio.

| Entrega | Conteúdo | Estado |
|---|---|---|
| 1 | Motor: escolhas, recursos, ações padrão, oportunidade, condições, Maestria, talentos, antecedentes; dados de todas as características | **Concluída** (0.6.6) |
| 2 | Marciais: Bárbaro (Berserker), Guerreiro (Campeão), Ladino (Ladrão), Monge (Mão Aberta) | **Concluída** (0.6.7) |
| 3 | Meio-conjuradores: Paladino (Devoção), Patrulheiro (Caçador) | **Concluída** (0.6.8) |
| 4 | Conjuradores: Bardo (Conhecimento), Clérigo (Vida), Druida (Terra + Forma Selvagem) | **Concluída** (0.6.9) |
| 5 | Conjuradores: Feiticeiro (Dracônica + Metamagia), Bruxo (Corruptor + Invocações), Mago (Evocador) | **Concluída** (0.6.10) |
| 6 | Magias de 2º a 9º círculo exigidas pelas características e subclasses | **Concluída** (0.6.11) |

## Fase 9 — resultado (2026-10-29)

- História completa em `docs/HISTORIA.md`, aprovada pelo responsável ("pode seguir com as propostas").
- Ato I com a camada da história: a Garra Vermelha, a cena no acampamento, o sonho com Vermeth, Ione e o gancho
  para Vessa, o epílogo e as Crônicas no diário. Tudo em dados (`data/story/`, `data/lore/`) avaliado pelo
  `StoryDirector` com as condições dos diálogos.
- Verificado em janela real: abertura, cena da Garra com Ignis e Kael, sonho na estalagem, Crônicas no diário e Ione.
- 287 testes passando.
- Próximo: Ato II (Vessa e a Academia de Mana, as Garras dos anões, orcs e elfos), conforme `docs/HISTORIA.md`.

## Companheiros recrutáveis — resultado (2026-10-27)

- Pedido do responsável: seis companheiros (classes e espécies diferentes) recrutados ao longo da campanha, grupo de
  protagonista + 2. Decisões: o jogador controla todos no combate; recrutamento por conversa e um pequeno pedido;
  quem não vai no grupo espera na estalagem e acompanha o nível do protagonista.
- `CompanionRoster` (recrutados, estalagem, montagem no nível do líder), `CompanionNpc` nos mapas, `PartyFollower`,
  painel do grupo na estalagem e `Tab` nos painéis. Tabela dos companheiros em `docs/VERTICAL_SLICE.md`.
- Verificado em janela real: NPCs nos três mapas, conversa com retrato pintado, seguidores, painel da estalagem, ficha
  com `Tab` e combate com três membros.
- 280 testes passando.
- Pendências: companheiros com IA própria (opcional), falas dos companheiros durante a aventura, testes contra a morte.

## Fase 8 — resultado (2026-10-27)

- Publicação no GitHub Pages pelo branch `gh-pages`, com `tools/publish/publish_web.sh`: testes, exportação,
  verificação dos arquivos e publicação do mesmo build validado (`--deploy`, só a partir de um commit limpo do `main`).
- Corrigido: a pasta `exports/` entrava no pacote (sem `.gdignore`); agora é ignorada e excluída do preset.
- Licença do conteúdo próprio: todos os direitos reservados (`LICENSE`). Avisos do Godot e dos componentes do motor em
  `ENGINE_LICENSES.txt`, publicado junto do jogo; atribuição do SRD em Créditos.
- Documentação: `docs/PUBLISHING.md` (como publicar, requisitos, limites da hospedagem, salvamento local e limitações
  conhecidas) e `README.md` com o endereço do jogo.
- Nome do jogo continua provisório (decisão do responsável).

## Fase 7 — resultado (2026-10-25)

- Aventura "A Garra-Rubra", do novo jogo à tela de conclusão: Vila de Ribeira (Ione, estalagem), Estrada da Vila com
  a criança perdida garantida, Clareira (Amara), Bosque do Riacho com o chefe Garra-Rubra e volta à vila.
  Roteiro e itens da especificação em `docs/VERTICAL_SLICE.md`.
- Objetivo atual sempre na tela; abertura ao começar; tela de conclusão com resumo, salvamento e "Continuar explorando".
- Arte nova gerada por código: casas, poço, Ione e Garra-Rubra. Vila montada pelo `build_overworld.gd` (layout `village`).
- Corrigido no caminho: a IA dos inimigos ignorava Ataques Múltiplos; acontecimentos "uma vez" valiam só por viagem.
- Verificado em janela real: abertura, conversa, objetivo, Clareira, acampamento do chefe, combate e conclusão.
- 268 testes passando.
- Pendências: arte de feras sem sprite próprio, testes de morte, companheiros com IA, mais conteúdo além da fatia.

## Fase 6.6, entrega 6 — resultado (2026-10-25)

- 34 magias de combate de 1º a 9º círculo (58 no total), áreas novas na grade e as características que dependiam delas
  (Arcano Místico, Maestria em Magia, Magias Assinatura, Palavras da Criação).
- Fora (escolha do responsável: "combate primeiro"): magias de exploração, invocação, muralhas e transformação —
  lista em `RULES_POLICY.md`.
- Verificado em janela real: mira da Bola de Fogo nas casas ao alcance, explosão e registro dos testes.
- 264 testes passando.

## Fase 6.6, entrega 5 — resultado (2026-10-25)

- Feiticeiro (Dracônica), Bruxo (Corruptor) e Mago (Evocador) funcionando dos níveis 1 a 20; exceções (invocações de
  exploração, Arcano Místico, Maestria em Magia, Magias Assinatura) em `RULES_POLICY.md`.
- Verificado em janela real: menus do Feiticeiro (Metamagia), do Bruxo e do Mago (Sobrecarga).
- 257 testes passando.

## Fase 6.6, entrega 4 — resultado (2026-10-25)

- Bardo (Conhecimento), Clérigo (Vida) e Druida (Terra) funcionando dos níveis 1 a 20, com Forma Selvagem em 11 feras;
  exceções (Palavras da Criação, Desejo, Falar com Animais, Encontrar Familiar) em `RULES_POLICY.md`.
- Verificado em janela real: menus do Clérigo, Druida e Bardo; druida vira lobo (sprite, PV temporários e "forma: Lobo").
- 248 testes passando.

## Fase 6.6, entrega 3 — resultado (2026-10-24)

- Paladino (Devoção) e Patrulheiro (Caçador) funcionando dos níveis 1 a 20, com magias sempre preparadas e usos
  sem espaço; exceções (Montaria Fiel, magias de 2º círculo+, Guerreiro Abençoado/Druídico) em `RULES_POLICY.md`.
- Verificado em janela real: menu do Paladino (Cura pelas Mãos, Canalizar Divindade, opções do Golpe Divino), pilar de
  luz do Golpe Divino, cura com efeito, Marca do Caçador com Saber do Caçador no registro.
- 236 testes passando.

## Fase 6.6, entrega 2 — resultado (2026-10-24)

- Bárbaro, Guerreiro, Ladino e Monge com as subclasses do SRD funcionando dos níveis 1 a 20 (exceto características
  de exploração listadas nas Adaptações de `RULES_POLICY.md`).
- Verificado em janela real: menu "Ações ▾" com as seções Classe e Opções; Fúria com aura; Rajada de Golpes.
- 226 testes passando.

## Fase 6.5 — resultado (2026-10-24)

- Conjuração completa para as 8 classes conjuradoras (tabelas 1–20), 16 magias do SRD 5.2.1 e efeitos visuais próprios.
- Concentração, efeitos por turno, áreas na grade, empurrão, cura, e um único espaço gasto por turno (2024).
- Verificado em janela real: cada estilo de efeito visual aparece no tabuleiro durante a conjuração.
- Pendências: escolher magias na subida de nível, magias de 2º círculo em diante, mais magias por classe (Clérigo e
  Bardo têm poucos truques), dardos de Mísseis Mágicos em alvos diferentes, conjurar cura fora do combate, inimigos
  conjuradores, conferir as tabelas de truques/preparadas acima do nível 2.

## Fase 6 — resultado (2026-10-24)

- `SaveGame` (formato, captura, validação, migração, aplicação) e autoload `SaveManager` (um slot em `user://`).
- Gravação segura: validação antes de gravar → arquivo temporário conferido → anterior vira cópia de recuperação →
  principal substituído e relido. Leitura tenta principal, temporário e cópia; arquivo cortado ou alterado é detectado
  pela soma SHA-256 do conteúdo.
- Autosave agrupado (0,4 s) só em pontos seguros: chegada a um mapa (troca de área, volta de combate, missão), fim de
  conversa, descanso, troca de equipamento e etapas da viagem. Espera enquanto há conversa, ação pendente, deslocamento
  ou combate começando.
- Menu do mapa (Esc): Continuar jogo, Salvar agora, Voltar ao título. Título: "Continuar" com resumo do salvamento e
  confirmação antes de um novo jogo substituir o salvamento.
- **Verificado no navegador** (build Web servido localmente): autosave e "Salvar agora" gravam; o salvamento continua
  após recarregar a página e após fechar a aba e abrir outra; "Continuar" volta ao mesmo lugar com a mesma aparência.
  IndexedDB não foi necessário além do que o Godot já usa para `user://`.
- Limitações: o salvamento fica no navegador e no endereço do site; limpar os dados do site, usar outro navegador ou
  janela anônima apaga/separa o progresso (a tela de título avisa quando o armazenamento não é permanente). Não há
  exportação/importação de salvamento (fora do escopo).
- Não testado: fechar o navegador inteiro (o painel só permite fechar a aba) e navegadores móveis.

## Arte dos personagens em alta resolução — resultado (2026-10-24)

- Personagens, goblin, lobo e retratos redesenhados em 64×64 (exibidos com 32 px no mundo): contorno de 1 pixel real,
  sombreamento em 5 tons com desvio de matiz, linhas internas, formas arredondadas e rosto pixel a pixel.
- Tamanhos do mundo, colisões e combate não mudaram. Cenário continua em 1×.
- Pendente: telas fora de 1280×720 com escala não inteira deixam pixels irregulares (avaliar escala inteira na Fase 8).

## Aparência modular das espécies — resultado (2026-10-24)

- Personagem desenhado por peças em tempo de execução (`CharacterPainter`), perfis por espécie em `data/appearance/`
  e seção "Aparência" com prévia animada na criação. A escolha aparece no mapa, nas falas, no combate e na viagem.
- Aasimar ficou de fora (não está no SRD 5.2.1). Referência visual do responsável guardada em `docs/art_reference/`.
- Pendente: mais peças (tatuagens faciais, cicatrizes variadas, armaduras por classe), aparência de companheiros,
  refinar o focinho do draconato visto de frente.

## Fase 5 — resultado

Critério: "o jogador pode explorar, lutar, receber recompensas, concluir uma missão e continuar a aventura". Atendido.

- Progressão pela tabela de XP do SRD (PV, Dados de Vida, proficiência, características de nível 2 das 12 classes).
- Inventário do grupo com ouro, Poção de Cura e Rações; equipar/trocar/remover com treinamento; poção no combate como
  ação bônus; recompensas de encontro (goblins) e de missão.
- Guarda Amara (sprite e retrato novos) com diálogo em dados e duas missões encadeadas: "Ameaça na Ruína" e
  "Notícias do Bosque" (esta usa a viagem da Fase 4).
- Telas: Inventário (I) e Diário (J); avisos de objetivo cumprido e de subida de nível.
- Testes: 170/170 (24 novos). O executor de testes passou a reprovar scripts que não compilam e erros de script
  durante um teste — isso revelou um teste da Fase 4 que vinha passando sem executar até o fim (corrigido).
- Verificação visual com sonda em janela real (conversa com retrato e escolhas, diário, inventário, poção no combate);
  corrigido o foco adiado em botões de diálogo já removidos.

## Fase 4 — resultado

Critério: "uma viagem pode gerar eventos, iniciar combates e continuar após a resolução dos encontros". Atendido.

- Região Floresta Sussurrante com tabela de encontros (3 combates, 5 eventos), rota de ida e volta entre a Clareira da
  Encruzilhada e o novo mapa Bosque do Riacho (riacho, acampamento com fogueira).
- `EncounterDirector` (dia/noite, eventos únicos, sem repetir o último, orçamento de XP) e `TravelSystem` (trechos,
  relógio, rações, fome, eventos com escolhas e testes de perícia, combate pendente, descansos, chegada).
- Tela de viagem com o herói andando pela trilha; combate da viagem volta para a viagem; chegada no mapa de destino.
- Descanso curto (Dados de Vida) e longo; fogueira no mapa; personagem no esquema 2 com migração do esquema 1.
- Testes: 146/146 (25 novos), incluindo 40 viagens completas simuladas e o fluxo mapa → viagem → combate → viagem → mapa.
  Checagem de mutação: desligar o filtro dia/noite e o piso de 1 PV derruba exatamente os testes correspondentes.
- Verificação visual com sonda em janela real (placa com confirmação, viagem, evento, resultado, Bosque do Riacho);
  corrigido o herói da trilha desenhado por cima do painel de evento.

## Reforma visual — resultado (2026-10-24)

Pedido do desenvolvedor antes da Fase 4: personagens animados e visual 2D mais bonito (direção 16 bits).

- Herói e goblin com 4 direções (parado, caminhada com pernas e braços alternando, ataque com rastro); lobo com
  caminhada e bote; retrato redesenhado. Tudo original, gerado por código (`tools/art/`).
- Terreno com transições suaves (terra, areia, água animada), moldura de floresta, árvores, pinheiros, arbustos e
  pedras com sombra; ruína com muro de topo e face e chão de terra batida.
- Exploração: personagem anda e se vira nas 4 direções. Combate: fichas andam entre casas, investem ao atacar,
  alvo pisca e treme, números de dano sobem, barra de PV desce no acerto, quem cai tomba.
- Verificado com sonda visual em janela real (capturas do mapa, da fala com retrato e de cada etapa do ataque);
  testes 121/121.

## Fase 3 — resultado

Critério: "um combate completo pode ser iniciado, resolvido e encerrado sem quebrar o estado do jogo". Atendido.

- Regras de ataque, dano, críticos, resistência, armas (proficiência, acuidade, versátil, arremesso) e desvantagem à distância.
- `CombatManager` com estados explícitos, comandos validados e IA determinística; Lobo e Goblin Guerreiro do SRD.
- Cena de combate em grade (clique para mover/atacar), ordem de iniciativa, registro com as rolagens, vitória/derrota/fuga.
- Dois encontros no mapa de teste (lobo a sudeste, goblin na ruína); retorno ao mapa na mesma posição com PV e XP.
- Falas com retrato do personagem em destaque e nome (pedido do desenvolvedor), começando pela placa.
- Testes: 121/121 (37 novos), incluindo 60 combates completos simulados com sementes diferentes.
- Bug encontrado no navegador e corrigido: troca de cena dentro do callback de física do gatilho; confirmado com
  sonda de troca de cena real.

## Conteúdo pós-Fase 2 — todas as classes e espécies (2026-10-23)

- As 12 classes e as 9 espécies do SRD 5.2.1 no nível 1, mais 10 armas para os kits iniciais.
- Defesa sem Armadura (Bárbaro, Monge) e Sentidos Aguçados (Elfo) implementados; demais características registradas.
- Testes: 84/84; as 216 combinações classe × espécie × antecedente geram personagens válidos.

## Fase 2 — resultado

Critério: "o personagem pode ser criado, consultado e salvo sem inconsistências conhecidas". Atendido, com o salvamento
limitado à serialização validada (gravação/leitura de arquivo testada; o `SaveManager` com slot e autosave é a Fase 6).

- Motor de regras SRD 5.2.1 em `scripts/rules/` (lista completa em `docs/RULES_POLICY.md`).
- Conteúdo em JSON validado: 2 classes, 2 espécies, 2 antecedentes, 11 itens; diagnósticos com arquivo, id e campo.
- Criação de personagem com prévia ao vivo; ficha no mapa com a tecla C; personagem mantido entre cenas.
- Créditos com a atribuição CC BY 4.0 do SRD, aviso de produto não oficial e aviso do Godot.
- Testes: 73/73 passando (55 novos). Dois bugs reais encontrados pelos próprios testes e corrigidos:
  CA de armadura pesada aplicava Destreza negativa; `versatile_damage` vazio explícito era rejeitado.
- Navegador (build Web): conteúdo carregado do `.pck`, criação (troca de classe, perícias, limite de escolhas, erros na prévia),
  início da aventura, ficha no mapa (abre com C, fecha com Esc), créditos. Sem erros no console.

## Fase 1 — resultado

- Mapa de teste 60×34 com colisões; movimento em 8 direções; câmera limitada; placa interativa. 18 testes na época.

## Fase 0 — resultado

- Ambiente: Windows 11, Git 2.51, Godot 4.7.2-stable (`C:\Users\ovito\Tools\Godot`), templates Web 4.7.2, Python 3.12.
- Projeto importa sem erros; roda no desktop (OpenGL 3.3) e na Web (WebGL 2, sem threads).

## Problemas conhecidos

- O projeto está dentro do OneDrive: `.godot/` e `exports/` (ignorados pelo Git, não pelo OneDrive) são sincronizados.
- ~~Avanço da tela de título sem input~~ — **não é bug**: o painel de navegador é compartilhado e os avanços eram cliques
  do próprio desenvolvedor jogando no painel (confirmado com instrumentação: evento de mouse entrando na janela e menus abertos
  sem ação do agente). Ao testar no painel, o agente deve avisar antes para não haver interação simultânea.
- Fontes pequenas (8–9 px na resolução interna, 16–18 px na tela em 1280×720): legíveis, mas revisar na direção de UI.

## Decisões pendentes (responsável do projeto)

- Licença do código e dos assets próprios (`LICENSE` ainda não criado).
- Biblioteca de testes: manter o executor próprio ou adotar GUT/gdUnit4 (ambos MIT).
- Mais classes/espécies/antecedentes do SRD no MVP, ou manter os dois de cada até o vertical slice.

## Pendências da viagem

- Emboscada ao acampar, exaustão por fome, clima, mais regiões e rotas com escolha de caminho.
- Mapa-múndi (hoje a rota é escolhida pela placa).
- Confirmar no SRD 5.2.1 se a cura por Dado de Vida tem mínimo de 1.

## Pendências do combate

- Testes de morte, condições, reações (ataques de oportunidade), ações bônus, Esquivar/Disparada/Desengajar.
- Companheiros com IA própria (hoje o jogador controla todo o grupo).
- Descanso para recuperar PV; sem ele, os PV perdidos ficam até um novo jogo.
- Animações de ataque/dano (hoje o registro e as barras de PV mostram o resultado).

## Próxima tarefa concreta

Todas as fases da especificação estão concluídas. Próximos passos, a decidir com o responsável: nome definitivo do jogo,
Ato II da campanha (`docs/HISTORIA.md`), testes contra a morte, reações de monstros, mais conteúdo (mapas, missões, monstros), áudio e
arte das feras da Forma Selvagem.
