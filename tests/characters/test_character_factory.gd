extends "res://tests/base_test.gd"
## Criação de personagem, ficha derivada e validação das escolhas.

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


## Guerreiro humano soldado: FOR 15+2, DES 13, CON 14+1, INT 8, SAB 12, CAR 10.
func fighter_choices() -> Dictionary:
	return {
		"id": "character.test_fighter",
		"name": "Brena",
		"species_id": "species.human",
		"class_id": "class.fighter",
		"background_id": "background.soldier",
		"ability_method": "standard_array",
		"base_scores": {&"str": 15, &"dex": 13, &"con": 14, &"int": 8, &"wis": 12, &"cha": 10},
		"background_increases": {&"str": 2, &"con": 1},
		"class_skills": [&"perception", &"survival"],
		"species_skills": [&"insight"],
		"expertise": [],
	}


## Ladino anão criminoso: DES 15+2, CON 14+1; Especialização em Furtividade e Percepção.
func rogue_choices() -> Dictionary:
	return {
		"id": "character.test_rogue",
		"name": "Tomas",
		"species_id": "species.dwarf",
		"class_id": "class.rogue",
		"background_id": "background.criminal",
		"ability_method": "standard_array",
		"base_scores": {&"str": 8, &"dex": 15, &"con": 14, &"int": 12, &"wis": 13, &"cha": 10},
		"background_increases": {&"dex": 2, &"con": 1},
		"class_skills": [&"acrobatics", &"perception", &"investigation", &"deception"],
		"species_skills": [],
		"expertise": [&"stealth", &"perception"],
	}


func _create(choices: Dictionary) -> CharacterData:
	var result := CharacterFactory.create(choices, _registry())
	assert_true(result[0] != null, "Criação deveria funcionar: %s" % str(result[1]))
	return result[0]


func _assert_rejected(choices: Dictionary, fragment: String, message: String) -> void:
	var result := CharacterFactory.create(choices, _registry())
	var errors: Array = result[1]
	var found := errors.any(func(e: String) -> bool: return e.contains(fragment))
	assert_true(result[0] == null and found, "%s (esperado erro com '%s'; erros: %s)" % [message, fragment, str(errors)])


func test_fighter_sheet() -> void:
	var c := _create(fighter_choices())
	if c == null:
		return
	var sheet := CharacterSheet.build(c, _registry())
	assert_eq(sheet.scores[&"str"], 17, "FOR 15 + 2")
	assert_eq(sheet.scores[&"con"], 15, "CON 14 + 1")
	assert_eq(sheet.modifiers[&"str"], 3, "Modificador de FOR 17")
	assert_eq(sheet.proficiency_bonus, 2, "Proficiência nível 1")
	assert_eq(sheet.armor_class, 18, "Cota de Malha 16 + Escudo 2")
	assert_eq(sheet.max_hp, 12, "d10 + Con +2")
	assert_eq(c.current_hp, 12, "Começa com PV cheios")
	assert_eq(sheet.speed, 30, "FOR 17 atende a Cota de Malha")
	assert_eq(sheet.initiative, 1, "Des 13")
	assert_eq(sheet.saving_throw_bonus(&"str"), 5, "Resistência de FOR proficiente")
	assert_eq(sheet.saving_throw_bonus(&"dex"), 1, "Resistência de DES sem proficiência")
	assert_eq(sheet.skill_bonus(&"athletics"), 5, "Atletismo do antecedente")
	assert_eq(sheet.skill_bonus(&"perception"), 3, "Percepção escolhida na classe (SAB 12)")
	assert_eq(sheet.skill_bonus(&"insight"), 3, "Intuição da espécie")
	assert_eq(sheet.skill_bonus(&"stealth"), 1, "Furtividade sem proficiência")
	assert_eq(sheet.passive_perception, 13, "10 + 3")
	assert_true(sheet.stealth_disadvantage, "Cota de Malha impõe desvantagem em Furtividade")
	assert_eq(c.weapon_ids, ["item.longsword"] as Array[String], "Kit inicial do Guerreiro")


func test_rogue_sheet_with_expertise_and_species_bonus() -> void:
	var c := _create(rogue_choices())
	if c == null:
		return
	var sheet := CharacterSheet.build(c, _registry())
	assert_eq(sheet.armor_class, 14, "Couro 11 + Des +3")
	assert_eq(sheet.max_hp, 11, "d8 + Con +2 + Robustez Anã +1")
	assert_eq(sheet.skill_bonus(&"stealth"), 7, "Furtividade (antecedente) com Especialização: 3 + 4")
	assert_eq(sheet.skill_bonus(&"perception"), 5, "Percepção com Especialização: 1 + 4")
	assert_eq(sheet.skill_bonus(&"acrobatics"), 5, "Acrobacia proficiente: 3 + 2")
	assert_true(sheet.skills[&"stealth"]["expertise"], "Marca de Especialização")
	assert_eq(sheet.saving_throw_bonus(&"int"), 3, "Resistência de INT proficiente: 1 + 2")
	assert_true(not sheet.stealth_disadvantage, "Couro não atrapalha a furtividade")
	assert_true(sheet.features.any(func(f: Dictionary) -> bool: return f["id"] == "trait.dwarven_toughness"), "Traços da espécie na ficha")
	assert_true(sheet.features.any(func(f: Dictionary) -> bool: return f["id"] == "feat.alert"), "Talento de origem na ficha")


func test_stealth_disadvantage_from_armor_is_applied_and_cancels_with_advantage() -> void:
	var sheet := CharacterSheet.build(_create(fighter_choices()), _registry())
	var check := sheet.roll_skill_check(&"stealth", 10, DiceRoller.scripted([18, 3]))
	assert_eq(check.advantage, D20Test.Advantage.DISADVANTAGE, "Armadura impõe desvantagem")
	assert_eq(check.natural, 3, "Usa o menor dado")
	check = sheet.roll_skill_check(&"stealth", 10, DiceRoller.scripted([18, 3]), D20Test.Advantage.ADVANTAGE)
	assert_eq(check.advantage, D20Test.Advantage.NONE, "Vantagem e desvantagem se anulam")
	assert_eq(check.natural, 18, "Rola um único dado")


func test_saving_throw_and_ability_check_rolls() -> void:
	var sheet := CharacterSheet.build(_create(fighter_choices()), _registry())
	var save := sheet.roll_saving_throw(&"con", 15, DiceRoller.scripted([11]))
	assert_eq(save.total, 15, "11 + CON (2) + proficiência (2)")
	assert_true(save.success, "Resistência bem-sucedida")
	var check := sheet.roll_ability_check(&"int", 10, DiceRoller.scripted([10]))
	assert_eq(check.total, 9, "10 + INT (-1)")
	assert_true(not check.success, "Teste falha")


func test_rejects_invalid_choices() -> void:
	var choices := fighter_choices()
	choices["name"] = "   "
	_assert_rejected(choices, "Informe um nome", "Nome vazio")

	choices = fighter_choices()
	choices["class_skills"] = [&"perception", &"stealth"]
	_assert_rejected(choices, "não é opção da classe", "Perícia fora da lista da classe")

	choices = fighter_choices()
	choices["class_skills"] = [&"perception", &"athletics"]
	_assert_rejected(choices, "já é proficiente por outra fonte", "Perícia repetida com o antecedente")

	choices = fighter_choices()
	choices["class_skills"] = [&"perception"]
	_assert_rejected(choices, "Escolha 2 perícia(s) da classe", "Quantidade de perícias")

	choices = fighter_choices()
	choices["species_skills"] = []
	_assert_rejected(choices, "Escolha 1 perícia(s) da espécie", "Humano escolhe uma perícia")

	choices = rogue_choices()
	choices["expertise"] = [&"stealth", &"history"]
	_assert_rejected(choices, "Especialização exige proficiência", "Especialização sem proficiência")

	choices = rogue_choices()
	choices["expertise"] = [&"stealth"]
	_assert_rejected(choices, "Especialização", "Quantidade de especializações")

	choices = fighter_choices()
	choices["base_scores"] = {&"str": 15, &"dex": 15, &"con": 14, &"int": 8, &"wis": 12, &"cha": 10}
	_assert_rejected(choices, "Arranjo padrão", "Arranjo padrão inválido")

	choices = fighter_choices()
	choices["background_increases"] = {&"wis": 2, &"con": 1}
	_assert_rejected(choices, "não permite aumentar", "Aumento fora dos atributos do antecedente")

	choices = fighter_choices()
	choices["species_id"] = "species.dragon"
	_assert_rejected(choices, "Espécie desconhecida", "Espécie inexistente")


func test_point_buy_character() -> void:
	var choices := fighter_choices()
	choices["ability_method"] = "point_buy"
	choices["base_scores"] = {&"str": 15, &"dex": 15, &"con": 15, &"int": 8, &"wis": 8, &"cha": 8}
	var c := _create(choices)
	if c != null:
		assert_eq(CharacterSheet.build(c, _registry()).scores[&"str"], 17, "Compra de pontos + antecedente")
	choices["base_scores"][&"int"] = 10
	_assert_rejected(choices, "Compra de pontos gasta", "Orçamento excedido")
