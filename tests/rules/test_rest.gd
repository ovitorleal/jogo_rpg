extends "res://tests/base_test.gd"
## Descanso curto (Dados de Vida), descanso longo e migração do personagem (esquema 1 -> 2).

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


## Guerreiro: d10, CON 15 (+2), 12 PV, 1 Dado de Vida.
func _fighter() -> CharacterData:
	return CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), _registry())[0]


func test_spend_hit_die_heals_die_plus_con() -> void:
	var c := _fighter()
	c.current_hp = 3
	var result := Rest.spend_hit_die(c, _registry(), DiceRoller.scripted([4]))
	assert_true(result["ok"], "Gasta o dado: %s" % result.get("error", ""))
	assert_eq(c.current_hp, 9, "3 + (4 + 2)")
	assert_eq(c.hit_dice_spent, 1, "Um Dado de Vida gasto")
	assert_eq(Rest.hit_dice_left(c), 0, "Nível 1: só um Dado de Vida")
	var again := Rest.spend_hit_die(c, _registry(), DiceRoller.scripted([4]))
	assert_true(not again["ok"] and again["error"].contains("Sem Dados de Vida"), "Sem dados restantes")


func test_hit_die_healing_is_capped_and_blocked_at_max_or_zero() -> void:
	var c := _fighter()
	c.current_hp = 11
	Rest.spend_hit_die(c, _registry(), DiceRoller.scripted([10]))
	assert_eq(c.current_hp, 12, "Não passa do máximo")
	var full := _fighter()
	assert_true(not Rest.spend_hit_die(full, _registry(), DiceRoller.scripted([5]))["ok"], "Com PV cheios, não gasta")
	var down := _fighter()
	down.current_hp = 0
	assert_true(not Rest.spend_hit_die(down, _registry(), DiceRoller.scripted([5]))["ok"], "Inconsciente não gasta")


func test_long_rest_restores_hp_and_hit_dice() -> void:
	var c := _fighter()
	c.current_hp = 2
	c.hit_dice_spent = 1
	var healed := Rest.long_rest(c, _registry())
	assert_eq([c.current_hp, c.hit_dice_spent, healed], [12, 0, 10], "PV e Dados de Vida completos")


func test_migration_from_schema_1() -> void:
	var data := _fighter().to_dict()
	data.erase("hit_dice_spent")
	data["schema_version"] = 1
	var result := CharacterData.from_dict(JSON.parse_string(JSON.stringify(data)))
	var loaded: CharacterData = result[0]
	assert_true(loaded != null, "Save da versão 1 carrega: %s" % str(result[1]))
	if loaded != null:
		assert_eq(loaded.hit_dice_spent, 0, "Migração define hit_dice_spent = 0")
		assert_eq(loaded.to_dict()["schema_version"], 2, "Salvo de novo na versão atual")
		assert_eq(CharacterFactory.validate(loaded, _registry()), [] as Array[String], "Personagem migrado é válido")
	assert_eq(int(data["schema_version"]), 1, "A migração não altera o dicionário original")


func test_invalid_hit_dice_spent_fails_validation() -> void:
	var c := _fighter()
	c.hit_dice_spent = 3
	assert_true(str(CharacterFactory.validate(c, _registry())).contains("Dados de Vida gastos"), "Mais dados gastos que o nível")
