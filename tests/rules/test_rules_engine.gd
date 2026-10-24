extends "res://tests/base_test.gd"
## Regras básicas do SRD 5.2.1: modificadores, proficiência, testes, CA, PV, deslocamento
## e geração de atributos.

const LEATHER := {"armor_category": "light", "base_ac": 11, "dex_cap": -1}
const CHAIN_SHIRT := {"armor_category": "medium", "base_ac": 13, "dex_cap": 2}
const CHAIN_MAIL := {"armor_category": "heavy", "base_ac": 16, "dex_cap": 0, "strength_requirement": 13}


func test_ability_modifier_table() -> void:
	var expected := {1: -5, 2: -4, 3: -4, 8: -1, 9: -1, 10: 0, 11: 0, 12: 1, 13: 1, 15: 2, 18: 4, 20: 5, 30: 10}
	for score: int in expected:
		assert_eq(Ability.modifier(score), expected[score], "Modificador de %d" % score)


func test_format_modifier() -> void:
	assert_eq(Ability.format_modifier(3), "+3", "Positivo")
	assert_eq(Ability.format_modifier(0), "+0", "Zero")
	assert_eq(Ability.format_modifier(-1), "-1", "Negativo")


func test_proficiency_bonus_by_level() -> void:
	var expected := {1: 2, 4: 2, 5: 3, 8: 3, 9: 4, 12: 4, 13: 5, 16: 5, 17: 6, 20: 6}
	for level: int in expected:
		assert_eq(RulesEngine.proficiency_bonus(level), expected[level], "Proficiência no nível %d" % level)
	assert_eq(RulesEngine.proficiency_bonus(0), 2, "Nível abaixo do mínimo é limitado")
	assert_eq(RulesEngine.proficiency_bonus(25), 6, "Nível acima do máximo é limitado")


func test_test_bonus_with_proficiency_and_expertise() -> void:
	assert_eq(RulesEngine.test_bonus(14, false, false, 1), 2, "Sem proficiência: só o modificador")
	assert_eq(RulesEngine.test_bonus(14, true, false, 1), 4, "Proficiente no nível 1: +2")
	assert_eq(RulesEngine.test_bonus(14, true, true, 1), 6, "Especialização dobra a proficiência")
	assert_eq(RulesEngine.test_bonus(14, false, true, 1), 2, "Especialização sem proficiência não conta")
	assert_eq(RulesEngine.test_bonus(14, true, false, 5), 5, "Proficiente no nível 5: +3")


func test_passive_score() -> void:
	assert_eq(RulesEngine.passive_score(3), 13, "Passivo normal")
	assert_eq(RulesEngine.passive_score(3, D20Test.Advantage.ADVANTAGE), 18, "Vantagem: +5")
	assert_eq(RulesEngine.passive_score(3, D20Test.Advantage.DISADVANTAGE), 8, "Desvantagem: -5")


func test_armor_class() -> void:
	assert_eq(RulesEngine.armor_class(14, {}), 12, "Sem armadura: 10 + Des")
	assert_eq(RulesEngine.armor_class(16, LEATHER), 14, "Leve: base + Des completa")
	assert_eq(RulesEngine.armor_class(18, CHAIN_SHIRT), 15, "Média: Des limitada a +2")
	assert_eq(RulesEngine.armor_class(8, CHAIN_SHIRT), 12, "Média: Des negativa se aplica")
	assert_eq(RulesEngine.armor_class(18, CHAIN_MAIL), 16, "Pesada: ignora Des positiva")
	assert_eq(RulesEngine.armor_class(8, CHAIN_MAIL), 16, "Pesada: ignora Des negativa")
	assert_eq(RulesEngine.armor_class(12, CHAIN_MAIL, 2), 18, "Escudo soma +2")
	assert_eq(RulesEngine.armor_class(12, {}, 2), 13, "Escudo sem armadura")


func test_max_hit_points() -> void:
	assert_eq(RulesEngine.max_hit_points(1, 10, 14), 12, "d10, Con +2, nível 1: 10 + 2")
	assert_eq(RulesEngine.max_hit_points(2, 10, 14), 20, "Nível 2: + (6 + 2)")
	assert_eq(RulesEngine.max_hit_points(3, 10, 14), 28, "Nível 3: + (6 + 2)")
	assert_eq(RulesEngine.max_hit_points(1, 6, 8), 5, "d6, Con -1, nível 1")
	assert_eq(RulesEngine.max_hit_points(2, 6, 8), 8, "d6, Con -1, nível 2: + (4 - 1)")
	assert_eq(RulesEngine.max_hit_points(2, 6, 1), 2, "Con -5: no mínimo 1 PV por nível")
	assert_eq(RulesEngine.max_hit_points(1, 10, 14, 1), 13, "Bônus por nível no nível 1")
	assert_eq(RulesEngine.max_hit_points(3, 10, 14, 1), 31, "Bônus por nível no nível 3")


func test_initiative_and_speed() -> void:
	assert_eq(RulesEngine.initiative_bonus(16), 3, "Iniciativa = modificador de Destreza")
	assert_eq(RulesEngine.speed(30, {}, 8), 30, "Sem armadura")
	assert_eq(RulesEngine.speed(30, CHAIN_MAIL, 13), 30, "Força suficiente para armadura pesada")
	assert_eq(RulesEngine.speed(30, CHAIN_MAIL, 12), 20, "Força insuficiente: -10 pés")


func test_standard_array_validation() -> void:
	var valid := {&"str": 15, &"dex": 14, &"con": 13, &"int": 12, &"wis": 10, &"cha": 8}
	assert_true(RulesEngine.validate_standard_array(valid).is_empty(), "Arranjo válido")
	var duplicated := valid.duplicate()
	duplicated[&"cha"] = 15
	assert_true(not RulesEngine.validate_standard_array(duplicated).is_empty(), "Valor repetido é inválido")
	var missing := valid.duplicate()
	missing.erase(&"cha")
	assert_true(not RulesEngine.validate_standard_array(missing).is_empty(), "Atributo faltando é inválido")
	var unknown := valid.duplicate()
	unknown[&"luck"] = 10
	assert_true(not RulesEngine.validate_standard_array(unknown).is_empty(), "Atributo desconhecido é inválido")


func test_point_buy_validation() -> void:
	var all_eight := {&"str": 8, &"dex": 8, &"con": 8, &"int": 8, &"wis": 8, &"cha": 8}
	assert_true(RulesEngine.validate_point_buy(all_eight).is_empty(), "Tudo 8 custa 0")
	var full := {&"str": 15, &"dex": 15, &"con": 15, &"int": 8, &"wis": 8, &"cha": 8}
	assert_eq(RulesEngine.point_buy_cost(full), 27, "Três 15 custam 27")
	assert_true(RulesEngine.validate_point_buy(full).is_empty(), "27 pontos é o limite")
	var over := full.duplicate()
	over[&"int"] = 9
	assert_true(not RulesEngine.validate_point_buy(over).is_empty(), "28 pontos excede o orçamento")
	var too_high := all_eight.duplicate()
	too_high[&"str"] = 16
	assert_true(not RulesEngine.validate_point_buy(too_high).is_empty(), "16 está fora do intervalo")
	var too_low := all_eight.duplicate()
	too_low[&"str"] = 7
	assert_true(not RulesEngine.validate_point_buy(too_low).is_empty(), "7 está fora do intervalo")


func test_background_increase_validation() -> void:
	var allowed := ["str", "dex", "con"]
	var base := {&"str": 15, &"dex": 14, &"con": 13, &"int": 12, &"wis": 10, &"cha": 8}
	assert_true(RulesEngine.validate_background_increase({&"str": 2, &"con": 1}, allowed, base).is_empty(), "+2/+1")
	assert_true(RulesEngine.validate_background_increase({&"str": 1, &"dex": 1, &"con": 1}, allowed, base).is_empty(), "+1/+1/+1")
	assert_true(not RulesEngine.validate_background_increase({&"str": 2, &"dex": 2}, allowed, base).is_empty(), "+2/+2 é inválido")
	assert_true(not RulesEngine.validate_background_increase({&"str": 3}, allowed, base).is_empty(), "+3 é inválido")
	assert_true(not RulesEngine.validate_background_increase({&"int": 2, &"con": 1}, allowed, base).is_empty(), "Atributo fora da lista")
	assert_true(not RulesEngine.validate_background_increase({}, allowed, base).is_empty(), "Sem aumento é inválido")
	var high := base.duplicate()
	high[&"str"] = 19
	assert_true(not RulesEngine.validate_background_increase({&"str": 2, &"con": 1}, allowed, high).is_empty(), "Não passa de 20")
