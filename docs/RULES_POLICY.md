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

## Conteúdo do SRD utilizado (dados em `data/`)

- Classes: Guerreiro, Ladino (somente nível 1: PV, resistências, perícias, treinamentos, Especialização do Ladino).
- Espécies: Humano (perícia extra), Anão (Robustez Anã; resistência a veneno e visão no escuro registradas, sem efeito ainda).
- Antecedentes: Soldado, Criminoso (atributos, perícias, ferramenta e talento de origem registrados).
- Itens: Couro, Couro Batido, Camisão de Malha, Brunea, Cota de Malha, Escudo, Adaga, Espada Curta, Espada Longa, Rapieira, Arco Curto.
- Descrições são resumos próprios em português; nomes de regras traduzidos livremente.

## Adaptações

| Adaptação | Motivo |
|---|---|
| Kit inicial simplificado: Guerreiro com Cota de Malha, Escudo e Espada Longa; Ladino com Couro, Espada Curta, 2 Adagas e Arco Curto | Apenas itens já cadastrados; o pacote de aventureiro, munição, ferramentas e PO entram com o inventário (Fase 5) |
| Humano sempre tamanho Médio | Escolha de tamanho ainda não exposta na criação |
| Unidades em pés nos dados e na ficha | Conversão para a grade de combate (quadrados de 5 pés) na Fase 3 |

## Pendências

- Características marcadas `"implemented": false` nos dados (aparecem na ficha como "ainda não implementada"):
  Estilo de Luta, Retomar o Fôlego, Maestria em Armas, Ataque Furtivo, Gíria de Ladrão, Engenhoso, Versátil, Visão no Escuro,
  Resiliência Anã (efeito), Conhecimento da Pedra, talentos de origem (Atacante Selvagem, Alerta).
- Ataques, dano, críticos, condições e descansos: Fase 3 em diante.
- Experiência e subida de nível: Fase 5.
- Treinamento com armas (simples/marciais) registrado, mas ainda sem efeito (ataques na Fase 3).
- Compra de pontos na tela de criação.
