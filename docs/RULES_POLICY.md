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

## Conteúdo do SRD utilizado (dados em `data/`)

- Classes (as 12, somente nível 1: dado de vida, resistências, perícias, treinamentos, kit, características):
  Bárbaro, Bardo, Clérigo, Druida, Guerreiro, Monge, Paladino, Patrulheiro, Ladino, Feiticeiro, Bruxo, Mago.
- Espécies (as 9): Draconato, Anão, Elfo, Gnomo, Golias, Pequenino, Humano, Orc, Tiefling — tamanho, deslocamento,
  visão no escuro e traços.
- Antecedentes: Soldado, Criminoso (atributos, perícias, ferramenta e talento de origem registrados).
  Acólito e Sábio, também do SRD, ainda não cadastrados.
- Armaduras: Couro, Couro Batido, Camisão de Malha, Brunea, Cota de Malha, Escudo.
- Armas: Adaga, Azagaia, Bordão, Clava, Foice, Lança, Maça, Machadinha, Arco Curto (simples); Cimitarra, Espada Curta,
  Espada Longa, Machado Grande, Rapieira, Arco Longo (marciais).
- Monstros: Lobo e Goblin Guerreiro (CA, PV, dados de vida, deslocamento, atributos, ataques, ND e XP).
- Descrições são resumos próprios em português; nomes de regras traduzidos livremente.

## Adaptações

| Adaptação | Motivo |
|---|---|
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

## Pendências

- Características marcadas `"implemented": false` nos dados (aparecem na ficha como "ainda não implementada"), entre elas:
  Conjuração/Magia de Pacto de todas as classes conjuradoras (sistema de magias ainda não existe), Fúria, Artes Marciais,
  Inspiração de Bardo, Estilo de Luta, Retomar o Fôlego, Maestria em Armas, Ataque Furtivo, Cura pelas Mãos, traços de espécie
  com escolha ou efeito em combate, talentos de origem (Atacante Selvagem, Alerta).
- Testes de morte, condições (Caído, Inconsciente com efeitos, Amedrontado...), reações, ações bônus, Desengajar/Esquivar/Disparada.
- Derrubar da mordida do Lobo e Fuga Ágil do Goblin (registrados como não implementados).
- Descanso curto/longo (hoje os PV perdidos só voltam com um novo personagem).
- Experiência e subida de nível: Fase 5.
- Treinamento com armas (simples/marciais) registrado, mas ainda sem efeito (ataques na Fase 3).
- Compra de pontos na tela de criação.
