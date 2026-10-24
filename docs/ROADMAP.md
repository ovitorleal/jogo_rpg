# Roadmap

| Fase | Descrição | Estado |
|---|---|---|
| 0 | Fundação técnica | Concluída (2026-10-23) |
| 1 | Primeiro mapa | Concluída (2026-10-23) |
| 2 | Modelo de personagens | **Concluída** (2026-10-23) |
| 3 | Combate | Próxima |
| 4 | Viagens e encontros | — |
| 5 | Progressão e conteúdo | — |
| 6 | Salvamento e integração | — |
| 7 | Vertical slice | — |
| 8 | Publicação | — |

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

## Próxima tarefa concreta

Fase 3 (combate), primeira fatia: `scripts/combat/` com `CombatManager` (estado explícito: preparação → iniciativa → turnos →
fim), ordem de iniciativa com desempate determinístico, ataque corpo a corpo e à distância (bônus de ataque com proficiência em
armas, Força/Destreza e acuidade, 20 natural = crítico, 1 natural = erro), dano com dados de crítico dobrados, PV e morte/derrota
simplificada; um monstro do SRD em `data/monsters/`; testes de regras antes da cena de combate.
