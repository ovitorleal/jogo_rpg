# Política de regras

- Base: **SRD 5.2.1** (regras revisadas de 2024), CC BY 4.0 — https://www.dndbeyond.com/srd
- Não misturar regras de 2014. Qualquer adaptação deve ser registrada abaixo com justificativa.
- Somente mecânicas do SRD ou material original. Nada de suplementos, nomes ou cenários protegidos.
- Toda regra fica em `scripts/rules/` (`RulesEngine` e auxiliares), independente da apresentação, e tem testes em `tests/rules/`.
- Aleatoriedade sempre via `DiceRoller` (semente configurável; valores roteirizados nos testes).
- A atribuição do SRD aparece no jogo (tela de título → Créditos) e em `THIRD_PARTY_NOTICES.md`.

## Regras implementadas

| Regra | Onde | Notas |
|---|---|---|
| Atributos 1–30 e modificador `floor((valor - 10) / 2)` | `Ability` | |
| Bônus de proficiência por nível (+2 a +6) | `RulesEngine.proficiency_bonus` | |
| Testes de atributo, perícia e resistência (Teste de d20) | `D20Test`, `CharacterSheet.roll_*` | Total ≥ CD = sucesso |
| 20/1 natural **sem** sucesso/falha automáticos em testes e resistências | `D20Test` | Regra de 2024; vale só para ataques (Fase 3) |
| Vantagem/desvantagem: 2d20 maior/menor; qualquer quantidade das duas se anula | `D20Test.resolve_advantage` | |
| Proficiência e Especialização (dobra a proficiência) | `RulesEngine.test_bonus` | |
| 18 perícias e atributo associado | `Skill` | |
| Valores passivos: 10 + bônus, ±5 por vantagem/desvantagem | `RulesEngine.passive_score` | |
| CA: sem armadura 10 + Des; leve + Des; média + Des (máx. +2); pesada sem Des; escudo +2 | `RulesEngine.armor_class` | Des negativa se aplica em leve/média, não em pesada |
| PV máximos: nível 1 = dado máximo + Con; demais níveis = média fixa (dado/2 + 1) + Con, mínimo 1 por nível | `RulesEngine.max_hit_points` | Rolagem de PV por nível não implementada |
| Iniciativa = modificador de Destreza | `RulesEngine.initiative_bonus` | Talento Alerta ainda não soma |
| Armadura pesada sem a Força exigida: −10 pés de deslocamento | `RulesEngine.speed` | |
| Armadura com desvantagem em Furtividade | `CharacterSheet.roll_skill_check` | Combina com outras fontes pela regra de anulação |
| Geração de atributos: arranjo padrão (15, 14, 13, 12, 10, 8) e compra de pontos (8–15, 27 pontos) | `RulesEngine.validate_*` | A tela de criação usa só o arranjo padrão por enquanto |
| Aumento do antecedente: +2/+1 ou +1/+1/+1 nos três atributos listados, máximo 20 | `RulesEngine.validate_background_increase` | Espécies não dão aumento de atributo (2024) |
| Proficiências repetidas de fontes diferentes não são permitidas: escolher outra | `CharacterFactory` | |
| Defesa sem Armadura: Bárbaro 10 + Des + Con (escudo permitido); Monge 10 + Des + Sab (sem armadura e sem escudo) | `RulesEngine.armor_class`, `CharacterSheet` | Usa o maior cálculo disponível, então nunca reduz a CA |
| Sentidos Aguçados do Elfo: proficiência em Intuição, Percepção ou Sobrevivência | dados `extra_skill_options` | Habilidoso do Humano: qualquer perícia |
| Traços de espécie com nível mínimo (Voo Dracônico, Forma Grande: nível 5) só aparecem a partir desse nível | `CharacterSheet` | |

### Combate (Fase 3)

| Regra | Onde | Notas |
|---|---|---|
| Iniciativa: d20 + modificador de Destreza | `CombatManager.start` | Empates: maior bônus, maior Destreza, grupo antes dos inimigos, id (adaptação determinística) |
| Jogada de ataque: d20 + bônus ≥ CA acerta; 20 natural sempre acerta e é Acerto Crítico; 1 natural sempre erra | `Attack.roll_attack` | |
| Dano: dados da arma + modificador; no crítico os dados são rolados duas vezes (modificador uma vez); mínimo 0 | `Attack.roll_damage` | |
| Resistência: metade, arredondando para baixo; vulnerabilidade: dobro | `Attack.apply_damage_modifiers` | Resistência a veneno do Anão já vale em combate |
| Bônus de ataque com arma: Força (corpo a corpo) ou Destreza (distância); Acuidade usa o maior; + proficiência se treinado | `Attack.weapon_attacks` | Treinamentos: simples, marciais, marciais com Acuidade/Leve (Ladino), marciais Leves (Monge) |
| Versátil: dano de duas mãos quando não há escudo | `Attack.weapon_attacks` | |
| Arremesso: arma corpo a corpo com Arremesso vira também ataque à distância (alcance normal/longo) | `Attack.weapon_attacks` | |
| Ataque Desarmado: Força + proficiência; dano 1 + Força, contundente | `Attack.unarmed_strike` | |
| Desvantagem à distância além do alcance normal e com inimigo adjacente; inválido além do alcance longo | `CombatManager.attack_advantage` | |
| Vantagem e desvantagem se anulam (qualquer quantidade) | `D20Test.resolve_advantage` | |
| Turno: uma ação e movimento igual ao deslocamento; quadrados de 5 pés, diagonal também 5 pés | `CombatManager` | Atravessa aliados, não inimigos; não termina em casa ocupada |
| Táticas de Matilha (Lobo): vantagem com aliado a até 5 pés do alvo | `CombatManager.attack_advantage` | |
| Monstro a 0 PV morre; personagem a 0 PV cai inconsciente; grupo todo a 0 PV = derrota | `CombatManager` | Testes de morte ainda não implementados |
| XP do encontro dividido igualmente entre o grupo na vitória | `CombatManager.apply_results_to_party` | |

### Descanso e viagem (Fase 4)

| Regra | Onde | Notas |
|---|---|---|
| Dados de Vida: total = nível; descanso curto gasta um por vez e recupera 1 dado + Con | `RulesEngine.spend_hit_die`, `Rest` | Mínimo 0 por dado (**a conferir** no SRD 5.2.1 se há mínimo de 1) |
| Descanso longo: recupera todos os PV e todos os Dados de Vida gastos | `Rest.long_rest` | |
| Personagem com 0 PV não gasta Dados de Vida | `Rest.spend_hit_die` | |
| Testes de perícia em eventos de viagem usam a ficha do líder (com desvantagem de armadura em Furtividade) | `TravelSystem.choose_option` | |
| Dano de perigos aplica resistências da espécie (ex.: veneno no Anão) | `TravelSystem.choose_option` | |

### Progressão e itens (Fase 5)

| Regra | Onde | Notas |
|---|---|---|
| Tabela de XP por nível (300, 900, 2.700, 6.500... 355.000) | `Progression.XP_FOR_LEVEL` | |
| Ao subir de nível: PV máximos pela média fixa + Con; PV atuais sobem o mesmo; Dados de Vida = nível; proficiência recalculada | `Progression.level_up` | Personagem a 0 PV não se levanta ao subir |
| Nível não pode passar do permitido pela experiência | `CharacterFactory.validate` | |
| Poção de Cura: 2d4+2 PV; beber é **ação bônus** | `Inventory.use`, `CombatManager._do_use_item` | Regra de 2024 |
| Uma ação bônus por turno | `CombatManager.bonus_action_available` | Por enquanto só poções usam a ação bônus |
| Rações (1 dia) como item do SRD | `data/items/supplies.json` | |

### Magias (Fase 6.5)

| Regra | Onde | Notas |
|---|---|---|
| CD de magia = 8 + atributo de conjuração + proficiência; ataque mágico = atributo + proficiência | `Spellcasting.save_dc/attack_bonus` | Atributo por classe em `data/classes/*.json` |
| Espaços por nível: conjuradores completos, meio-conjuradores (Paladino e Patrulheiro desde o nível 1, regra de 2024) e Magia de Pacto | `Spellcasting.FULL_SLOTS/HALF_SLOTS/PACT_*` | Tabelas dos níveis 1–20 |
| Truques conhecidos e magias preparadas por nível | `cantrips_known`/`prepared_spells` nas classes | **Conferir** os níveis acima de 2 com o SRD 5.2.1 antes do vertical slice |
| Magia em círculo maior usa o menor espaço livre que comporta; dados extras por círculo (`upcast_dice`), +1 dardo em Mísseis Mágicos, +1 alvo em Bênção | `Spellcasting.lowest_slot/scaled_dice` | |
| Truques: dados ×2/×3/×4 nos níveis 5/11/17 | `Spellcasting.cantrip_multiplier` | |
| Só um espaço de magia gasto por turno | `CombatManager.slot_used_this_turn` | Regra de 2024 (substitui a restrição antiga de ação bônus) |
| Ataque mágico segue as regras de ataque (20 crítico, 1 erra, vantagem/desvantagem, inimigo adjacente em ataque à distância) | `CombatManager._resolve_spell_on` | |
| Teste de resistência contra a CD do conjurador; metade do dano com sucesso quando a magia diz | idem | Monstros usam o modificador do atributo (goblin e lobo não têm proficiência em resistências) |
| Concentração: nova magia de concentração encerra a anterior; dano exige teste de Constituição CD max(10, metade do dano), até 30; cair encerra | `CombatManager._apply_damage/_end_concentration` | |
| Descanso longo recupera todos os espaços; Magia de Pacto também no descanso curto | `Rest.long_rest`, `Spellcasting.short_rest` | |
| Efeitos com duração "até o início/fim do próximo turno" | `CombatManager._expire_effects` | Raio de Gelo, Zombaria Viciosa, Raio Guiador |

### Ações, reações, condições e talentos (Fase 6.6, entrega 1)

| Regra | Onde | Notas |
|---|---|---|
| Ação de Ataque: um golpe por ataque; Ataque Extra (2), Dois Ataques Extras (3) e Três Ataques Extras (4); pode mover entre os golpes | `CombatManager.attacks_per_action/_use_attack` | Pelas características `feature.extra_attack` etc. |
| Disparada (movimento extra igual ao deslocamento), Desengajar (sem ataques de oportunidade no turno), Esquivar (ataques contra têm desvantagem; vantagem em Destreza) | `CombatManager._do_standard_action` | Como ação bônus só com característica (Ação Astuta) |
| Ataque de oportunidade: reação, ataque corpo a corpo quando um inimigo sai do alcance; uma reação por rodada | `CombatManager._do_move/_can_opportunity_attack` | Feito automaticamente por personagens e monstros |
| Condições do glossário: Cego, Enfeitiçado, Amedrontado, Agarrado, Incapacitado, Invisível, Paralisado, Petrificado, Envenenado, Caído, Contido, Atordoado, Inconsciente | `CombatManager.add_condition`, `attack_advantage`, `_roll_save`, `effective_speed` | Vantagem/desvantagem, falha automática em Força/Destreza, deslocamento 0, crítico automático a 1,5 m, levantar-se custa metade do deslocamento |
| Exaustão: -2 x nível nos Testes de d20, -1,5 m x nível no deslocamento; descanso longo reduz 1 | `CharacterData.exhaustion`, `CombatManager._exhaustion` | Fontes de Exaustão ainda não existem no jogo |
| PV temporários absorvem o dano primeiro | `CombatManager._apply_damage` | |
| Ataque Desarmado: Dano, Agarrar ou Empurrar (teste de Força ou Destreza contra CD 8 + Força + proficiência); escapar com Atletismo/Acrobacia | `Attack.unarmed_options`, `CombatManager._resolve_unarmed_option/_try_escape_grapple` | Empurrar derruba (Caído) |
| Arma Pesada: desvantagem com Força (corpo a corpo) ou Destreza (distância) menor que 13 | `CombatManager.attack_advantage` | |
| Propriedade Leve: ataque extra com outra arma Leve como ação bônus, sem modificador no dano (salvo negativo) | `CombatManager._do_offhand` | |
| Maestria em Armas: Trespassar, Raspar, Talhar, Empurrar, Enfraquecer, Lentidão, Derrubar, Atormentar | `CombatManager._apply_mastery_on_hit`, `Attack.MASTERY_*` | Só nas armas escolhidas na característica Maestria em Armas |
| Talentos de origem: Alerta (proficiência na iniciativa), Iniciado em Magia (2 truques + magia de 1º com uso gratuito por descanso longo), Atacante Selvagem (uma vez por turno rola o dano duas vezes), Habilidoso (3 perícias) | `CharacterSheet.build`, `Combatant.from_character`, `CombatManager._weapon_damage` | |
| Aumento no Valor de Atributo (+2 ou +1/+1, máximo 20) e Dádivas Épicas (+1, máximo 30) nos níveis de talento | `CharacterChoices`, `CharacterData.ability_score` | |
| Estilos de Luta: Arquearia (+2 à distância), Defesa (+1 CA com armadura), Armas Grandes (1 e 2 viram 3 em arma de duas mãos/versátil empunhada com as duas), Duas Armas (modificador no ataque extra Leve) | `Combatant.from_character`, `CharacterSheet.build`, `CombatManager._weapon_damage` | |
| Recursos de classe com usos por descanso curto, um por descanso curto ou longo | `ClassFeatures`, `Rest.long_rest`, `TravelSystem.short_rest` | Tabelas conferidas com o SRD 5.2.1 (modo texto) |

### Classes marciais (Fase 6.6, entrega 2)

Ganchos em `CombatFeatures` (estáticos, recebem o `CombatManager`); ações no menu "Ações ▾" pelo comando `feature`,
opções marcáveis pelo comando `option`.

| Classe | Características com efeito | Notas |
|---|---|---|
| Bárbaro | Fúria (ação bônus; dano de Fúria por nível; resistência a contundente/cortante/perfurante; vantagem em Força; dura enquanto atacar/forçar teste ou estender com ação bônus; sem conjurar/concentrar), Defesa sem Armadura, Ataque Imprudente, Sentido de Perigo, Ataque Extra, Movimento Rápido, Instinto Feroz, Golpe Brutal (abre mão da vantagem: +1d10 e Golpe Forte/Jarrete; nível 13: Golpe Cambaleante/Rasgante; nível 17: +2d10 e dois efeitos), Fúria Implacável (CD 10, +5 por uso), Fúria Persistente, Poderio Indomável, Campeão Primitivo | Berserker: Frenesi (dano extra = dados de dano de Fúria), Fúria Irracional (imune a Enfeitiçado/Amedrontado em Fúria), Retaliação (reação), Presença Intimidante |
| Guerreiro | Estilo de Luta, Retomar o Fôlego (1d10 + nível), Surto de Ação (uma vez por turno; sem ação de Magia), Mente Tática (+1d10 em teste falho; só gasta se der certo), Ataque Extra (2/3/4 golpes), Indomável (rola de novo com +nível), Ataques Estudados, Mestre Tático | Campeão: Crítico Aprimorado (19) e Superior (18), Atleta Notável (vantagem na iniciativa; após crítico, meio deslocamento sem oportunidade), Guerreiro Heroico (Inspiração Heroica no início do turno), Sobrevivente (recupera 5 + CON abaixo de metade dos PV; vantagem em testes de morte registrada) |
| Ladino | Ataque Furtivo (vantagem, ou aliado a 1,5 m sem desvantagem; uma vez por turno), Ação Astuta, Golpe Astuto (Envenenar, Tropeçar, Recuar) e Golpes Engenhosos (Atordoar, Nocautear, Obscurecer), Mira Firme, Esquiva Sobrenatural (reação: metade do dano), Evasão, Talento Confiável (d20 mínimo 10 em perícias proficientes), Mente Escorregadia, Elusivo, Golpe de Sorte | Ladrão: Reflexos de Ladrão (dois turnos na primeira rodada) |
| Monge | Artes Marciais (Destreza, dado marcial, golpe desarmado como ação bônus), Foco (Rajada de Golpes, Defesa Paciente, Passo do Vento), Defesa sem Armadura, Movimento sem Armadura, Metabolismo Sobrenatural, Desviar Ataques (com redirecionar), Golpe Atordoante, Ataques Fortalecidos (dano de energia), Evasão, Autorrestauração, Foco Perfeito, Defesa Superior, Corpo e Mente | Mão Aberta: Técnica da Mão Aberta (Desequilibrar, Empurrar, Derrubar), Integridade do Corpo, Passo Ligeiro, Palma Trêmula (10d12 de energia; metade se passar) |

## Conteúdo do SRD utilizado (dados em `data/`)

- Classes (as 12, somente nível 1: dado de vida, resistências, perícias, treinamentos, kit, características):
  Bárbaro, Bardo, Clérigo, Druida, Guerreiro, Monge, Paladino, Patrulheiro, Ladino, Feiticeiro, Bruxo, Mago.
- Espécies (as 9): Draconato, Anão, Elfo, Gnomo, Golias, Pequenino, Humano, Orc, Tiefling — tamanho, deslocamento,
  visão no escuro e traços.
- Antecedentes: os 4 do SRD (Acólito, Criminoso, Sábio, Soldado), cada um com seu talento de origem.
- Talentos: os 17 do SRD (4 de origem, 2 gerais, 4 de Estilo de Luta, 7 Dádivas Épicas).
- Características das 12 classes dos níveis 1 a 20 e das 12 subclasses do SRD (Berserker, Conhecimento, Vida, Terra,
  Campeão, Mão Aberta, Devoção, Caçador, Ladrão, Dracônica, Corruptor, Evocador); o indicador `implemented` diz quais
  já têm efeito.
- Armaduras: Couro, Couro Batido, Camisão de Malha, Brunea, Cota de Malha, Escudo.
- Armas: Adaga, Azagaia, Bordão, Clava, Foice, Lança, Maça, Machadinha, Arco Curto (simples); Cimitarra, Espada Curta,
  Espada Longa, Machado Grande, Rapieira, Arco Longo (marciais).
- Monstros: Lobo e Goblin Guerreiro (CA, PV, dados de vida, deslocamento, atributos, ataques, ND e XP).
- Magias (16): truques Raio de Fogo, Raio de Gelo, Spray Venenoso, Chama Sagrada, Rajada Mística, Zombaria Viciosa;
  1º círculo Mísseis Mágicos, Mãos Flamejantes, Onda Trovejante, Raio Guiador, Curar Ferimentos, Palavra Curativa,
  Escudo da Fé, Bênção, Marca do Caçador, Maldição.
- Itens: Poção de Cura e Rações (1 dia); características de nível 2 das 12 classes (registradas, sem efeito ainda).
- Descrições são resumos próprios em português; nomes de regras traduzidos livremente.

## Adaptações

| Adaptação | Motivo |
|---|---|
| Propriedades de Maestria e ataques de oportunidade são aplicados automaticamente (o jogo escolhe aplicar) | Evita perguntas a cada golpe; a escolha raramente é desfavorável |
| Ações Ajudar, Esconder, Influenciar, Preparar, Procurar, Estudar e Usar ainda não existem no combate | Dependem de cobertura, iluminação ou situações fora da grade atual |
| Troca de iniciativa do Alerta, partes sociais e de exploração das características ficam registradas sem efeito | Grupo de um personagem; sem sistema social/exploração detalhado |
| Agarrador e os efeitos das Dádivas Épicas (exceto o aumento de atributo) ainda não têm efeito | Ficam para as entregas das classes |
| Gíria de Ladrão, Mãos Rápidas, Trabalho no Segundo Andar, Furtividade Suprema, Usar Dispositivo Mágico, Queda Lenta e Movimento Acrobático registrados sem efeito | Dependem de Esconder, escalada, queda, itens mágicos ou idiomas, que ainda não existem |
| Golpe Brutal, Golpe Astuto, Golpe Atordoante e Técnica da Mão Aberta são escolhidos antes do ataque (opções marcadas no menu) e aplicados no próximo acerto que permitir | Evita interromper cada acerto com uma pergunta |
| Esquiva Sobrenatural, Desviar Ataques, Retaliação, Indomável e Golpe de Sorte são usados automaticamente quando ajudam | O grupo tem um personagem; perguntar a cada reação deixaria o combate lento |
| Fúria termina no fim do turno se o bárbaro não atacou nem forçou um teste e não estendeu com ação bônus | Leitura direta do SRD 5.2.1, sem o controle de "1 minuto" |
| Defesa Paciente, Passo do Vento e Rajada de Golpes sem Foco usam a ação bônus; a versão com Foco aparece como item separado | Duas entradas no menu em vez de uma pergunta |
| Testes de morte ainda não existem (Sobrevivente: só a parte de cura) | Derrota do grupo encerra o combate |
| Talentos/características com escolhas recebem padrões automáticos; o jogador troca na criação ou com a tecla L | Subir de nível nunca trava o jogo |
| Truques/preparadas limitados ao que existe na lista da classe (ex.: Clérigo conhece 1 truque em vez de 3; Bruxo prepara só Maldição) | Ainda há poucas magias cadastradas |
| Magias novas da subida de nível são escolhidas automaticamente (primeiras da lista) | Tela de escolha na subida de nível fica para depois |
| Mísseis Mágicos: todos os dardos no mesmo alvo | Escolha de alvos por dardo fica para depois |
| Cone de 4,5 m na grade = 7 casas (1-3-3) em linha reta ou 3x3 na diagonal; cubo de 4,5 m = 3x3 casas encostadas no conjurador | Modelos de área na grade de 5 pés |
| Marca do Caçador/Maldição: sem trocar a marca de alvo e sem a desvantagem em testes de atributo da Maldição | Fora do combate do MVP |
| Componentes (V, S, M), rituais, alcance de toque além de 5 pés e cobertura não são simulados | Sem regras de cobertura e inventário de componentes ainda |
| Inimigos não conjuram | Goblins e lobos do SRD não têm magias |
| Aparência (corpo, chifres, cauda, escamas...) é só visual; não altera regras. Aasimar fora (não está no SRD 5.2.1) | O SRD define traços de espécie por regras, não por aparência |
| Kit inicial simplificado: só armadura, escudo e armas da opção A de cada classe (o Guerreiro recebe Cota de Malha, Escudo e Espada Longa) | Pacotes, munição, focos, ferramentas e PO entram com o inventário (Fase 5) |
| Humano e Tiefling sempre tamanho Médio | Escolha de tamanho ainda não exposta na criação |
| Escolhas com efeito mecânico ainda não modeladas (Ancestral Dracônico, Legado Ínfero, Linhagens, Ordem Divina/Primal, Ancestral Gigante) | Registradas como características não implementadas; resistências que dependem delas ainda não aparecem na ficha |
| Unidades em pés nos dados e na ficha; grade de combate com quadrados de 5 pés | Padrão do SRD para grade |
| Fugir: usa a ação do turno e encerra o combate para o grupo inteiro, sem teste | Simplificação até existirem Desengajar e ataques de oportunidade |
| Sem reações (ataques de oportunidade) e sem ações bônus em combate | Fatia inicial da Fase 3 |
| Dados de vida dos monstros fixos na média do SRD (Lobo 11, Goblin 10) | Previsibilidade; o validador confere se a média cabe nos dados |
| Viagem em trechos: cada trecho consome 1 ração por membro; sem ração o grupo fica "com fome" e não pode acampar | Regra original simples até existirem exaustão e inventário |
| Descanso curto na viagem: 1 hora por Dado de Vida gasto; acampar: 8 horas e 1 ração por membro | Simplificação do tempo de descanso |
| Perigos de eventos nunca reduzem abaixo de 1 PV | Evitar derrota fora do combate no MVP |
| Orçamento de encontros: 100 XP × nível × membros (combates acima disso não são sorteados) | Heurística original do projeto (não é tabela do SRD) |
| Fogueira do mapa concede descanso longo sem custo | Ponto seguro de recuperação do protótipo |
| Equipar armadura/escudo exige o treinamento da classe (sem a regra de usar armadura sem treinamento) | Evitar estados que o combate ainda não penaliza |
| No máximo 6 armas equipadas por personagem; sem regras de mãos/sacar | Simplificação até existir o sistema de mãos |
| Recompensas de encontro/missão em PO e itens definidos nos dados | Conteúdo original |

## Pendências

- Características marcadas `"implemented": false` nos dados (aparecem na ficha como "ainda não implementada"): as das
  classes conjuradoras (entregas 3 a 5 da Fase 6.6), as exceções marciais listadas nas Adaptações e traços de espécie com
  escolha ou efeito em combate.
- Testes de morte, condições (Caído, Inconsciente com efeitos, Amedrontado...), reações, ações bônus, Desengajar/Esquivar/Disparada.
- Derrubar da mordida do Lobo e Fuga Ágil do Goblin (registrados como não implementados).
- Descanso curto/longo (hoje os PV perdidos só voltam com um novo personagem).
- Experiência e subida de nível: Fase 5.
- Treinamento com armas (simples/marciais) registrado, mas ainda sem efeito (ataques na Fase 3).
- Compra de pontos na tela de criação.
