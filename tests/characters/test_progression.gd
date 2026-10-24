extends "res://tests/base_test.gd"
## XP e níveis (tabela do SRD 5.2.1): limiares, subida de nível, PV, características e validação.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


## Guerreiro humano: d10, CON 15 (+2), 12 PV no nível 1.
func _fighter() -> CharacterData:
	return CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), _registry())[0]


func test_xp_thresholds() -> void:
	var expected := {0: 1, 299: 1, 300: 2, 899: 2, 900: 3, 2700: 4, 6500: 5, 14000: 6, 355000: 20, 999999: 20}
	for xp: int in expected:
		assert_eq(Progression.level_for_xp(xp), expected[xp], "Nível com %d XP" % xp)


func test_award_xp_levels_up_with_hp_and_features() -> void:
	var c := _fighter()
	c.current_hp = 10
	var ups := Progression.award_xp(c, 300, _registry())
	assert_eq(ups.size(), 1, "Sobe um nível")
	assert_eq([c.level, c.experience], [2, 300], "Nível 2 com 300 XP")
	var sheet := CharacterSheet.build(c, _registry())
	assert_eq(sheet.max_hp, 20, "12 + (6 + 2) pela média fixa")
	assert_eq(c.current_hp, 18, "PV atuais sobem na mesma quantidade (10 + 8)")
	assert_eq(ups[0]["hp_gained"], 8, "Ganho registrado")
	var names: Array = ups[0]["features"].map(func(f: Dictionary) -> String: return f["id"])
	assert_true("feature.action_surge" in names and "feature.tactical_mind" in names, "Características do nível 2: %s" % str(names))
	assert_eq(RulesEngine.hit_dice_total(c.level), 2, "Dois Dados de Vida")
	assert_true(Progression.describe(c, ups[0]).contains("nível 2") and Progression.describe(c, ups[0]).contains("Surto de Ação"),
			"Aviso de subida de nível")


func test_multiple_levels_at_once_and_proficiency() -> void:
	var c := _fighter()
	var ups := Progression.award_xp(c, 6500, _registry())
	assert_eq(ups.size(), 4, "Do 1 ao 5 de uma vez")
	assert_eq(c.level, 5, "Nível 5")
	assert_eq(CharacterSheet.build(c, _registry()).proficiency_bonus, 3, "Proficiência +3 no nível 5")
	assert_eq(Progression.xp_to_next(c), 14000 - 6500, "XP até o nível 6")


func test_unconscious_character_does_not_heal_on_level_up() -> void:
	var c := _fighter()
	c.current_hp = 0
	Progression.award_xp(c, 300, _registry())
	assert_eq(c.current_hp, 0, "Subir de nível não levanta quem está a 0 PV")


func test_level_higher_than_xp_is_invalid() -> void:
	var c := _fighter()
	c.level = 3
	c.current_hp = 1
	assert_true(str(CharacterFactory.validate(c, _registry())).contains("exige mais experiência"), "Nível sem XP suficiente")
	c.experience = 900
	assert_eq(CharacterFactory.validate(c, _registry()), [] as Array[String], "Com 900 XP o nível 3 é válido")
