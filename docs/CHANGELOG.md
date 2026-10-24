# Changelog

## [0.6.7] — 2026-10-24 — Fase 6.6, entrega 2: classes marciais

### Adicionado
- `CombatFeatures`: ganchos de combate das características (iniciativa, início/fim de turno, ataque, dano, acerto,
  dano recebido, PV 0, resistências e testes de resistência), ações de classe e opções marcáveis.
- Bárbaro e Berserker (níveis 1–20): Fúria com aura, Ataque Imprudente, Golpe Brutal, Fúria Implacável, Frenesi,
  Retaliação, Presença Intimidante, Campeão Primitivo e demais características.
- Guerreiro e Campeão: Retomar o Fôlego, Surto de Ação, Mente Tática (viagem), Indomável, Ataques Estudados, Mestre
  Tático, críticos aprimorados, Atleta Notável, Guerreiro Heroico e Sobrevivente.
- Ladino e Ladrão: Ataque Furtivo com Golpe Astuto e Golpes Engenhosos, Ação Astuta, Mira Firme, Esquiva
  Sobrenatural, Evasão, Talento Confiável, Elusivo, Golpe de Sorte e Reflexos de Ladrão.
- Monge e Mão Aberta: Artes Marciais, Foco (Rajada, Defesa Paciente, Passo do Vento), Desviar Ataques, Golpe
  Atordoante, Ataques Fortalecidos, Defesa Superior, Técnica da Mão Aberta, Integridade do Corpo e Palma Trêmula.
- Menu "Ações ▾": seções "Classe" (ações com usos restantes) e "Opções" (efeitos marcáveis); efeitos visuais e
  mensagens próprias no registro.
- 12 testes novos (total 226).

### Alterado
- 173 de 274 características marcadas com efeito nos dados das classes e subclasses.
## [0.6.6] — 2026-10-24 — Fase 6.6, entrega 1: motor de características, antecedentes e talentos

### Adicionado
- Antecedentes Acólito e Sábio (os 4 do SRD) e os 17 talentos do SRD (tipo de conteúdo `feat`).
- Características das 12 classes (níveis 1–20) e das 12 subclasses do SRD (tipo `subclass`), com recursos por nível
  (Fúria, Inspiração, Canalizar Divindade, Forma Selvagem, Foco, Pontos de Feitiçaria...) conferidos com o SRD.
- `CharacterChoices`: talento do antecedente, Aumento no Valor de Atributo/Dádiva Épica, Estilo de Luta, Maestria em
  Armas, perícias, Especialização, subclasse, Invocações e Metamagia — com padrões automáticos e validação.
- `ClassFeatures`: recursos com usos, recarga no descanso curto/longo e resumo na ficha.
- Combate: ação de Ataque com vários golpes (Ataque Extra), Disparada, Desengajar, Esquivar, ataque de oportunidade
  (reação), 13 condições, Exaustão, PV temporários, Agarrar/Empurrar, armas Pesadas e ataque extra Leve.
- Maestria em Armas: as 8 propriedades. Talentos Alerta, Iniciado em Magia, Atacante Selvagem, Habilidoso e os 4 estilos.
- Menu "Ações ▾" no combate; seção "Talentos e escolhas" na criação; tela "Escolhas de nível" no mapa (tecla L).
- `CharacterData` esquema 5 (subclasse, escolhas, recursos gastos, Exaustão) com migração.
- 16 testes novos (total 214).

### Corrigido
- Tabelas de truques e magias preparadas acima do nível 2 conferidas com o SRD (estavam corretas).
- Valores padrão de listas no validador de conteúdo eram compartilhados entre registros.

## [0.6.5] — 2026-10-24 — Fase 6.5: magias e efeitos visuais

### Adicionado
- Conjuração do SRD 5.2.1 (`Spellcasting`): CD e ataque mágico, espaços por nível (completos, meio-conjuradores e
  Magia de Pacto), truques e magias preparadas por classe, círculo superior, escala de truques, descansos.
- 16 magias (`data/spells/`, tipo de conteúdo `spell`) para as 8 classes conjuradoras: ataque mágico, resistência,
  dano automático, áreas (cone e cubo), cura, empurrão e efeitos (lentidão, zombaria, raio guiador, +CA, Bênção, marcas).
- Combate: comando `cast`, um único espaço gasto por turno, concentração com teste de Constituição, efeitos com
  duração por turno; magias no menu de ações com alvos marcados e direção de área em laranja.
- Efeitos visuais das magias (`SpellVfx`), desenhados por código: projétil com rastro, feixe, dardos, pilar de luz,
  névoa venenosa, ondas de zombaria, cone de chamas, onda de choque, cura, aura e runa de marca.
- Criação de personagem: seção "Magias" (truques e preparadas); ficha mostra CD, ataque, espaços e magias.
- `CharacterData` esquema 4 (truques, preparadas, espaços gastos); saves antigos recebem as magias padrão.
- 12 testes novos (total 198).

### Alterado
- Paladino, Patrulheiro e Bruxo: conjuração marcada como implementada; descanso curto recupera espaços de pacto.
- Subida de nível prepara magias novas automaticamente e avisa quais são.

## [0.6.0] — 2026-10-24 — Fase 6

### Adicionado
- Salvamento local com um slot (`SaveGame`, autoload `SaveManager`): esquema versionado com migração, soma SHA-256,
  validação completa, gravação segura (temporário + cópia de recuperação) e recuperação de arquivo danificado.
- Autosave agrupado em pontos seguros (mapa, combate resolvido, missão, conversa, descanso, equipamento, viagem).
- Indicador discreto "Salvando… / Jogo salvo / Falha ao salvar" em qualquer tela.
- Menu do mapa (Esc): Continuar jogo, Salvar agora, Voltar ao título.
- Título: "Continuar" com resumo do salvamento, aviso de armazenamento não permanente e confirmação de novo jogo.
- 8 testes novos (total 186).

### Verificado
- Build Web: o salvamento persiste ao recarregar a página e ao fechar/reabrir a aba.

## [0.5.2] — 2026-10-24 — Arte dos personagens em alta resolução

### Alterado
- Personagens jogáveis, herói padrão, Guarda Amara, goblin, lobo e retratos desenhados em 64×64 (2 pixels reais por
  pixel lógico) e exibidos no mesmo tamanho de antes: pixel art mais suave e nítida.
- `PixelCanvas`: fator de resolução `k`; com k > 1, sombreamento em 5 tons, linhas internas entre partes, contorno de
  1 pixel real, linhas com pincel redondo, `mask_round_rect` e `mask_polygon`. Com k = 1 o resultado é o mesmo de antes.
- `CharacterPainter`: rampas com desvio de matiz; tronco, membros, capa, mechas e escudo arredondados; orelhas
  pontudas em triângulo; chifres de carneiro em espiral; olhos, boca, sardas e marcas pixel a pixel.
- `SpriteLibrary` deduz o tamanho do quadro pela largura da folha; `attach()` ajusta escala e offset dos pés.
- `generate_characters.gd` usa o `CharacterPainter` para herói, Amara e goblin.
- Pintura otimizada (distâncias por programação dinâmica, linhas por distância ao segmento): ~0,45 s por folha
  64×64 no desktop. Na criação, a prévia é pintada uma direção por quadro e só quando a aparência muda.
- Presas de orc nos cantos da boca (antes pareciam lágrimas).

## [0.5.1] — 2026-10-24 — Aparência modular das espécies

### Adicionado
- `CharacterPainter`: desenha em tempo de execução a folha animada (9×4 quadros) e o retrato de cada personagem a partir
  de peças: corpo (Masculino/Feminino), porte, 12 penteados, 8 barbas, orelhas, chifres/cristas, caudas, marcas
  corporais, detalhes do rosto (sardas, presas, cicatriz...), acessórios, capa e cores de pele/escamas, cabelo, olhos,
  roupa e capa; armadura, escudo e arma refletem o equipamento.
- Tipo de conteúdo `appearance` (`data/appearance/`): perfil por espécie do SRD com opções, cores e proporções
  (anões e pequeninos mais baixos, golias alto, draconato com focinho, escamas e cauda, tiefling com chifres e cauda).
- `Appearance`: padrão da espécie, validação, sorteio e cache das texturas.
- Seção "Aparência" na criação de personagem, com prévia animada que gira, retrato e botões Aleatório/Girar.
- Folha de referência das espécies (gerada com IA pelo responsável) em `docs/art_reference/`, só como referência.
- 8 testes novos (total 178).

### Alterado
- `CharacterData` esquema 3 (`appearance`); saves v1/v2 migram com a aparência padrão da espécie.
- Jogador, combate, retrato de fala e faixa de viagem usam a aparência do líder; trocar equipamento atualiza o sprite.
- `PixelCanvas` mudou de `tools/art/` para `scripts/presentation/` (usado também em tempo de execução).

## [0.5.0] — 2026-10-24 — Fase 5

### Adicionado
- `Progression` (tabela de XP do SRD, subida de nível com PV e características); características de nível 2 das 12 classes.
- `Inventory` (pilhas, ouro, equipar/trocar/remover, consumíveis, recompensas, serialização); Poção de Cura e Rações.
- Ação bônus no combate e comando `use_item` (poção); botão "Poção" na cena de combate; recompensas dos encontros goblins.
- Missões (`QuestLog`, autoload `QuestManager`, `data/quests/`) e diálogos em dados (`DialogueRunner`, `data/dialogues/`).
- Guarda Amara (NPC com sprite e retrato) e duas missões encadeadas.
- Telas de Inventário (I) e Diário (J); escolhas de diálogo na caixa de fala.
- Ícones de itens; teste que carrega todos os scripts e cenas.
- 24 testes novos (total 170).

### Alterado
- Rações saíram de `PartyManager.supplies` e passaram ao inventário (`PartyManager.inventory`).
- XP concedido em combate, eventos e missões passa pela progressão (pode subir de nível).
- Executor de testes reprova scripts que não compilam e erros de script em tempo de execução.

### Corrigido
- Teste da tela de viagem que interrompia por erro de script e contava como aprovado.
- Foco adiado em botão de diálogo já removido.

## [0.4.0] — 2026-10-24 — Fase 4

### Adicionado
- Conteúdo: tipos `map`, `region`, `route`, `event` validados; Floresta Sussurrante, Estrada do Leste (ida e volta),
  5 eventos (descoberta, NPC, perigo) e 2 encontros novos (dois lobos à noite, batedor goblin de dia).
- `EncounterDirector`, `TravelSystem` (serializável, reproduzível com semente) e tela de viagem com `RouteStrip`.
- `Rest` (descanso curto com Dados de Vida e descanso longo); fogueira no mapa.
- Mapa novo Bosque do Riacho (layout `forest_brook` no `build_overworld.gd`); entradas `Entrances/*`.
- Placas de estrada com ação `travel:<rota>` e confirmação ([E] confirmar / [Esc] cancelar).
- Suprimentos do grupo (`PartyManager.supplies`, 6 rações iniciais).
- 25 testes novos (total 146).

### Alterado
- `CharacterData` esquema 2 (`hit_dice_spent`) com migração automática do esquema 1.
- `Interactable` ganhou `action`; HUD aceita dica personalizada na caixa de fala.
- Combate iniciado na viagem retorna para a viagem.

## [0.3.1] — 2026-10-24 — Reforma visual

### Adicionado
- `tools/art/`: biblioteca `PixelCanvas` (3 tons, contorno seletivo, sombra) e geradores de personagens,
  terreno e objetos; `build_overworld.gd` monta TileSet, terreno (marching squares) e objetos do mapa.
- Folhas animadas: herói e goblin (4 direções × parado/caminhada/ataque), lobo (2 direções); retrato novo.
- Atlas de terreno com transições e água animada; árvore, pinheiro, arbusto, pedra e placa como objetos.
- `SpriteLibrary` (animações a partir das folhas) e `CombatToken` (combatente animado).
- Combate animado: caminhada entre casas, investida de ataque, dano flutuante, piscar/tremor, queda.

### Alterado
- Jogador usa `AnimatedSprite2D` com direção; marcadores de encontro animados.
- Mapa de teste: camadas `Ground`/`Walls` dentro de `Terrain`, objetos de cenário em `Objects` (y-sort),
  borda de floresta com bloqueio invisível; lago elíptico com praia.
- Tabuleiro de combate com casas de 32 px sobre grama.
- Bíblia visual reescrita para a direção 16 bits.

### Removido
- Arte provisória da Fase 0–3 (`placeholder_*`) e `tools/placeholders/`, substituídas pela nova arte.

## [0.3.0] — 2026-10-24 — Fase 3

### Adicionado
- Regras de combate: `Attack` (ataque, crítico, dano, resistência, bônus de arma, desarmado, distância na grade).
- `Combatant`, `CombatManager` (iniciativa, turnos, movimento, ataques, IA, vitória/derrota/fuga, XP) e `CombatLog`.
- Cena de combate (`scenes/combat/combat_scene.tscn`) com tabuleiro clicável, iniciativa, registro e resultado.
- Monstros (`data/monsters/`: Lobo, Goblin Guerreiro) e encontros (`data/encounters/`), validados pelo registro.
- Autoload `ExplorationManager` e `EncounterTrigger`; dois encontros no mapa de teste.
- Falas com retrato e nome de quem fala; placa lida em voz alta pelo personagem.
- Retrato provisório do herói e sprites do Lobo e do Goblin (catalogados).
- 37 testes novos (total 121).

### Corrigido
- Início de combate removia a cena durante um callback de física.
- Mapa não quebra mais com grupo sem líder válido ao entrar numa área de encontro.

## [0.2.1] — 2026-10-23 — Todas as classes e espécies

### Adicionado
- 10 classes: Bárbaro, Bardo, Clérigo, Druida, Monge, Paladino, Patrulheiro, Feiticeiro, Bruxo, Mago (nível 1).
- 7 espécies: Draconato, Elfo, Gnomo, Golias, Pequenino, Orc, Tiefling.
- 10 armas: Clava, Machadinha, Azagaia, Maça, Bordão, Foice, Lança, Machado Grande, Cimitarra, Arco Longo.
- Defesa sem Armadura (Bárbaro: Con, com escudo; Monge: Sab, sem escudo).
- Campo `extra_skill_options` nas espécies (Sentidos Aguçados do Elfo) e treinamento `martial_light` (Monge).
- Ficha mostra tamanho, visão no escuro e resistências da espécie.
- 11 testes novos (total 84), incluindo as 216 combinações classe × espécie × antecedente.

### Corrigido
- Traços de espécie com nível mínimo apareciam na ficha do nível 1.

## [0.2.0] — 2026-10-23 — Fase 2

### Adicionado
- Motor de regras (SRD 5.2.1): `Ability`, `Skill`, `DiceRoller`, `DiceExpression`, `D20Test`, `RulesEngine`.
- Conteúdo em JSON com validação (`ContentSchema`, `ContentRegistry`, autoload `Content`): Guerreiro, Ladino, Humano, Anão,
  Soldado, Criminoso, 5 armaduras, escudo e 5 armas.
- Personagens: `CharacterData` (serialização versionada), `CharacterFactory` (criação e validação), `CharacterSheet` (ficha derivada).
- Autoload `PartyManager` (grupo entre cenas).
- Tela de criação de personagem com prévia da ficha ao vivo.
- Ficha no mapa (tecla C; Esc fecha) e dica "[C] Ficha" no HUD.
- Tela de Créditos com atribuição do SRD 5.2, aviso de produto não oficial e aviso do Godot.
- Ação de input `character_sheet`.
- 55 testes novos (total 73): regras, dados, conteúdo, criação, serialização, tela de criação, ficha no mapa, créditos.

### Alterado
- "Novo jogo" abre a criação de personagem antes do mapa.
- Exportação Web inclui `data/*.json`.
- Versão 0.1.0 → 0.2.0.

## [0.1.0] — 2026-10-23 — Fase 1

### Adicionado
- Mapa de teste (60×34 tiles 16×16) com colisões em muros, água, rochas e arbustos.
- Jogador (`Player`): movimento em 8 direções, colisão nos pés, câmera seguindo com limites do mapa.
- Componente `Interactable` e placa interativa com mensagem no HUD (`ExplorationHud`).
- Controlador de mapa `ExplorationMap`.
- Ações de input: `move_up/down/left/right` (WASD + setas) e `interact` (E, Espaço, Enter); nomes das camadas de física.
- Tileset provisório (8 tiles) e placa gerados por script; `build_test_map.gd` gera TileSet e terreno.
- `docs/ART_BIBLE.md` e `docs/ASSET_PIPELINE.md` provisórios.
- 11 testes novos (9 de exploração, 2 de configuração): total 18.

### Alterado
- "Novo jogo" agora abre o mapa de teste (antes mostrava aviso de não implementado).
- Versão 0.0.1 → 0.1.0.

## [0.0.1] — 2026-10-23 — Fase 0

### Adicionado
- Projeto Godot 4.7.2 (Compatibility Renderer, viewport 640×360, filtro Nearest para pixel art).
- Tela de título provisória com "Novo jogo" (aviso de não implementado), "Continuar" (desabilitado) e "Sair" (oculto na Web).
- Sprite provisório 32×32 gerado por script e ícone SVG provisório.
- Catálogo de assets (`assets/asset_catalog.json`).
- Executor de testes próprio e 7 testes de integração (configuração, cena de título, preset Web, catálogo).
- Preset de exportação Web sem threads.
- Documentação inicial: README, CLAUDE.md, ARCHITECTURE, ROADMAP, RULES_POLICY, CONTENT_LICENSES, THIRD_PARTY_NOTICES.
