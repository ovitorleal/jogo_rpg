# Roadmap

| Fase | Descrição | Estado |
|---|---|---|
| 0 | Fundação técnica | Concluída (2026-10-23) |
| 1 | Primeiro mapa | Concluída (2026-10-23) |
| 2 | Modelo de personagens | Concluída (2026-10-23) |
| 3 | Combate | **Concluída** (2026-10-24) |
| 4 | Viagens e encontros | Próxima |
| 5 | Progressão e conteúdo | — |
| 6 | Salvamento e integração | — |
| 7 | Vertical slice | — |
| 8 | Publicação | — |

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
- Herói tem um único quadro (sem animação de caminhada).
- Fontes pequenas (8–9 px na resolução interna, 16–18 px na tela em 1280×720): legíveis, mas revisar na direção de UI.
- Persistência de `user://` na Web ainda não verificada (Fase 6).

## Decisões pendentes (responsável do projeto)

- Nome definitivo do jogo (hoje `PROJECT_NAME`).
- Licença do código e dos assets próprios (`LICENSE` ainda não criado).
- Escala dos personagens: 32×32 (atual) ou 48×48.
- Biblioteca de testes: manter o executor próprio ou adotar GUT/gdUnit4 (ambos MIT).
- Mais classes/espécies/antecedentes do SRD no MVP, ou manter os dois de cada até o vertical slice.

## Pendências do combate

- Testes de morte, condições, reações (ataques de oportunidade), ações bônus, Esquivar/Disparada/Desengajar.
- Companheiros com IA (o grupo ainda tem só o líder).
- Descanso para recuperar PV; sem ele, os PV perdidos ficam até um novo jogo.
- Animações de ataque/dano (hoje o registro e as barras de PV mostram o resultado).

## Próxima tarefa concreta

Fase 4 (viagens e encontros): `data/regions/` com uma região e uma rota; `TravelSystem` com trechos, tempo e recursos;
`EncounterDirector` escolhendo encontros por região, nível do grupo e histórico (com semente); eventos sem combate
(descoberta, NPC, perigo ambiental); transição viagem → combate → continuação. Considerar descanso curto/longo junto,
para a viagem ter recuperação de PV.
