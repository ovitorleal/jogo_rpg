extends "res://tests/base_test.gd"
## Todas as combinações de classe × espécie × antecedente podem gerar um personagem válido,
## e as regras específicas de classe/espécie (Defesa sem Armadura, Sentidos Aguçados) funcionam.

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


## Escolhas padrão: atributos sugeridos da classe, +2/+1 nos dois primeiros atributos do
## antecedente e as primeiras perícias permitidas, sem repetir proficiências.
func _default_choices(class_id: String, species_id: String, background_id: String) -> Dictionary:
	var class_entry := _registry().get_entry("class", class_id)
	var species := _registry().get_entry("species", species_id)
	var background := _registry().get_entry("background", background_id)
	var scores := {}
	for i in 6:
		scores[Ability.ALL[i]] = int(class_entry["suggested_scores"][i])
	var taken: Array[StringName] = []
	for skill: Variant in background["skill_proficiencies"]:
		taken.append(StringName(skill))
	var class_skills := _pick(class_entry["skill_options"], int(class_entry["skill_choice_count"]), taken)
	taken.append_array(class_skills)
	var species_skills := _pick(CharacterFactory.species_skill_options(species), int(species["extra_skill_choices"]), taken)
	taken.append_array(species_skills)
	var expertise := _pick(taken, int(class_entry["expertise_choices"]), [] as Array[StringName])
	return {
		"name": "Teste",
		"species_id": species_id,
		"class_id": class_id,
		"background_id": background_id,
		"ability_method": "standard_array",
		"base_scores": scores,
		"background_increases": {StringName(background["ability_options"][0]): 2, StringName(background["ability_options"][1]): 1},
		"class_skills": class_skills,
		"species_skills": species_skills,
		"expertise": expertise,
	}


func _pick(options: Array, count: int, blocked: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for option: Variant in options:
		if result.size() >= count:
			break
		if not StringName(option) in blocked:
			result.append(StringName(option))
	return result


func _sheet(class_id: String, species_id: String, overrides: Dictionary = {}) -> CharacterSheet:
	var choices := _default_choices(class_id, species_id, "background.soldier")
	choices.merge(overrides, true)
	var result := CharacterFactory.create(choices, _registry())
	assert_true(result[0] != null, "%s/%s: %s" % [class_id, species_id, str(result[1])])
	return CharacterSheet.build(result[0], _registry()) if result[0] != null else null


func test_every_combination_creates_a_valid_character() -> void:
	var count := 0
	for class_id in _registry().ids("class"):
		for species_id in _registry().ids("species"):
			for background_id in _registry().ids("background"):
				var result := CharacterFactory.create(_default_choices(class_id, species_id, background_id), _registry())
				assert_true(result[0] != null, "%s + %s + %s: %s" % [class_id, species_id, background_id, str(result[1])])
				if result[0] != null:
					var sheet := CharacterSheet.build(result[0], _registry())
					assert_true(sheet.max_hp > 0 and sheet.armor_class >= 10, "%s + %s: PV e CA plausíveis" % [class_id, species_id])
				count += 1
	assert_eq(count, 12 * 9 * 2, "Combinações testadas")


func test_barbarian_unarmored_defense() -> void:
	# Bárbaro sugerido: FOR 15, DES 13, CON 14; Soldado +2 FOR +1 DES -> DES 14 (+2), CON 14 (+2).
	var sheet := _sheet("class.barbarian", "species.human")
	if sheet != null:
		assert_eq(sheet.armor_class, 14, "10 + Des 2 + Con 2")
		assert_eq(sheet.max_hp, 14, "d12 + Con 2")


func test_barbarian_unarmored_defense_never_lowers_ac() -> void:
	var scores := {&"str": 15, &"dex": 14, &"con": 8, &"int": 13, &"wis": 12, &"cha": 10}
	var sheet := _sheet("class.barbarian", "species.human", {"base_scores": scores,
			"background_increases": {&"str": 2, &"dex": 1}})
	if sheet != null:
		assert_eq(sheet.armor_class, 12, "Con -1 não reduz: usa 10 + Des 2")


func test_monk_unarmored_defense_and_shield_rule() -> void:
	# Monge sugerido: DES 15, SAB 14; Soldado +2 FOR +1 DES -> DES 16 (+3), SAB 14 (+2).
	var sheet := _sheet("class.monk", "species.human")
	if sheet == null:
		return
	assert_eq(sheet.armor_class, 15, "10 + Des 3 + Sab 2")
	var c := sheet.character
	c.shield_id = "item.shield"
	var with_shield := CharacterSheet.build(c, _registry())
	assert_eq(with_shield.armor_class, 15, "Com escudo, Monge perde a Defesa sem Armadura: 10 + 3 + 2 (escudo)")
	assert_true(str(CharacterFactory.validate(c, _registry())).contains("escudo"), "Monge sem treinamento com escudo")


func test_armor_replaces_unarmored_defense() -> void:
	var sheet := _sheet("class.barbarian", "species.human")
	if sheet == null:
		return
	var c := sheet.character
	c.armor_id = "item.leather_armor"
	assert_eq(CharacterSheet.build(c, _registry()).armor_class, 13, "Com armadura vale só a armadura: 11 + Des 2")


func test_elf_keen_senses_limits_skill_choice() -> void:
	var choices := _default_choices("class.fighter", "species.elf", "background.soldier")
	assert_true(choices["species_skills"][0] in [&"insight", &"perception", &"survival"], "Padrão dentro das opções")
	choices["species_skills"] = [&"stealth"]
	var result := CharacterFactory.create(choices, _registry())
	assert_true(result[0] == null and str(result[1]).contains("não é opção da espécie"), "Elfo não escolhe Furtividade")


func test_small_species_and_speed_on_sheet() -> void:
	var halfling := _sheet("class.rogue", "species.halfling")
	var goliath := _sheet("class.fighter", "species.goliath")
	if halfling != null:
		assert_eq(halfling.species["size"], "small", "Pequenino é Pequeno")
		assert_true(CharacterSheetPanel.format_sheet(halfling).contains("Tamanho: Pequeno"), "Tamanho na ficha")
	if goliath != null:
		assert_eq(goliath.speed, 35, "Golias tem 35 pés")


func test_level_gated_species_traits_hidden_at_level_1() -> void:
	var sheet := _sheet("class.fighter", "species.dragonborn")
	if sheet != null:
		assert_true(not sheet.features.any(func(f: Dictionary) -> bool: return f["id"] == "trait.draconic_flight"),
				"Voo Dracônico (nível 5) não aparece no nível 1")
		assert_true(CharacterSheetPanel.format_sheet(sheet).contains("Visão no escuro: 60"), "Visão no escuro na ficha")
