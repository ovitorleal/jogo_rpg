# Roadmap

| Fase | Descrição | Estado |
|---|---|---|
| 0 | Fundação técnica | Concluída (2026-10-23) |
| 1 | Primeiro mapa | **Concluída** (2026-10-23) |
| 2 | Modelo de personagens | Próxima |
| 3 | Combate | — |
| 4 | Viagens e encontros | — |
| 5 | Progressão e conteúdo | — |
| 6 | Salvamento e integração | — |
| 7 | Vertical slice | — |
| 8 | Publicação | — |

## Fase 1 — resultado

Critério: "o personagem pode andar pelo mapa, colidir com obstáculos e interagir com pelo menos um objeto". Atendido.

- Mapa de teste de 60×34 tiles: estradas, lago, ruína, rochas, arbustos. Muros, água, rochas e arbustos têm colisão.
- Personagem com movimento em 8 direções (WASD/setas), câmera com suavização limitada às bordas do mapa.
- Placa interativa: aviso "[E] Ler placa", mensagem com bloqueio de movimento, fechamento com E/Espaço/Enter.
- "Novo jogo" abre o mapa de teste.
- Testes: 18/18 passando (9 novos de exploração usando a física real do motor). Checagem de mutação: sem a máscara de
  colisão o jogador atravessa o muro (x = −25), confirmando que o teste de colisão detecta a regressão.
- Navegador (build Web, Chromium): título → mapa, movimento com câmera, aviso e mensagem da placa, sem erros no console.

## Fase 0 — resultado

- Ambiente: Windows 11, Git 2.51, Godot 4.7.2-stable (`C:\Users\ovito\Tools\Godot`), templates Web 4.7.2, Python 3.12.
- Projeto importa sem erros; roda no desktop (OpenGL 3.3) e na Web (WebGL 2, sem threads).

## Problemas conhecidos

- O projeto está dentro do OneDrive: `.godot/` e `exports/` (ignorados pelo Git, não pelo OneDrive) são sincronizados.
  Considerar mover o repositório ou excluir essas pastas da sincronização.
- Observado uma vez no navegador: a tela de título passou para o mapa sem input visível logo após abrir o painel do navegador.
  Não reproduzido em três recargas seguintes (mais de 12 s parado). Provável clique de foco no botão central; monitorar.
- Não há como voltar do mapa para o título (sem menu de pausa ainda).
- Herói tem um único quadro (sem animação de caminhada).
- Persistência de `user://` na Web ainda não verificada (Fase 6).

## Decisões pendentes (responsável do projeto)

- Nome definitivo do jogo (hoje `PROJECT_NAME`).
- Licença do código e dos assets próprios (`LICENSE` ainda não criado).
- Escala dos personagens: 32×32 (atual) ou 48×48.
- Biblioteca de testes: manter o executor próprio ou adotar GUT/gdUnit4 (ambos MIT).

## Próxima tarefa concreta

Fase 2: criar `scripts/rules/` com atributos e modificadores (SRD 5.2.1), proficiência por nível, testes de atributo/perícia/resistência
com vantagem/desvantagem e dado com semente configurável; modelo de dados de personagem serializável; testes em `tests/rules/`.
Ficha e criação básica de personagem vêm depois do motor de regras estar testado.
