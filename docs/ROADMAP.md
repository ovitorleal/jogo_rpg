# Roadmap

| Fase | Descrição | Estado |
|---|---|---|
| 0 | Fundação técnica | Concluída (2026-10-23) |
| 1 | Primeiro mapa | Concluída (2026-10-23) |
| 2 | Modelo de personagens | Concluída (2026-10-23) |
| 3 | Combate | Concluída (2026-10-24) |
| 4 | Viagens e encontros | Concluída (2026-10-24) |
| 5 | Progressão e conteúdo | **Concluída** (2026-10-24) |
| 6 | Salvamento e integração | Próxima |

Extras pós-Fase 5: aparência modular das espécies (0.5.1) e arte dos personagens em alta resolução (0.5.2), 2026-10-24 — ver abaixo.
| 7 | Vertical slice | — |
| 8 | Publicação | — |

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
- Não há como voltar do mapa para o título (sem menu de pausa ainda).
- Fontes pequenas (8–9 px na resolução interna, 16–18 px na tela em 1280×720): legíveis, mas revisar na direção de UI.
- Persistência de `user://` na Web ainda não verificada (Fase 6).

## Decisões pendentes (responsável do projeto)

- Nome definitivo do jogo (hoje `PROJECT_NAME`).
- Licença do código e dos assets próprios (`LICENSE` ainda não criado).
- Biblioteca de testes: manter o executor próprio ou adotar GUT/gdUnit4 (ambos MIT).
- Mais classes/espécies/antecedentes do SRD no MVP, ou manter os dois de cada até o vertical slice.

## Pendências da viagem

- Emboscada ao acampar, exaustão por fome, clima, mais regiões e rotas com escolha de caminho.
- Mapa-múndi (hoje a rota é escolhida pela placa).
- Confirmar no SRD 5.2.1 se a cura por Dado de Vida tem mínimo de 1.

## Pendências do combate

- Testes de morte, condições, reações (ataques de oportunidade), ações bônus, Esquivar/Disparada/Desengajar.
- Companheiros com IA (o grupo ainda tem só o líder).
- Descanso para recuperar PV; sem ele, os PV perdidos ficam até um novo jogo.
- Animações de ataque/dano (hoje o registro e as barras de PV mostram o resultado).

## Próxima tarefa concreta

Fase 6 (salvamento): `SaveManager` com um slot em `user://` (escrita temporária + troca segura, cópia de recuperação),
`schema_version` do save e migrações; salvar grupo (`CharacterData`), inventário, missões, estado de exploração e viagem;
autosave após combate, missão, troca de mapa e descanso; "Salvar agora" e "Continuar" no título; mensagens de sucesso/falha;
teste de persistência no navegador (recarregar a página e reabrir o navegador).
