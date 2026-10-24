extends "res://tests/base_test.gd"
## Validação de conteúdo: os dados reais carregam sem erros e cada tipo de defeito
## produz uma mensagem de diagnóstico útil.


func _real_registry() -> ContentRegistry:
	var registry := ContentRegistry.new()
	registry.load_all()
	return registry


## Dados válidos em memória, copiados do conteúdo real, para serem corrompidos nos testes.
func _valid_data() -> Dictionary:
	var registry := _real_registry()
	var data := {}
	for type_name: String in ContentRegistry.TYPES:
		data[type_name] = []
		for id in registry.ids(type_name):
			data[type_name].append(registry.get_entry(type_name, id).duplicate(true))
	return data


func _find(data: Dictionary, type_name: String, id: String) -> Dictionary:
	for entry: Dictionary in data[type_name]:
		if entry["id"] == id:
			return entry
	return {}


## Carrega "data" e confirma que há um erro contendo "fragment".
func _assert_error(data: Dictionary, fragment: String, message: String) -> void:
	var registry := ContentRegistry.new()
	var ok := registry.load_from_dictionaries(data)
	var found := registry.errors.any(func(e: String) -> bool: return e.contains(fragment))
	assert_true(not ok and found, "%s (esperado erro com '%s'; erros: %s)" % [message, fragment, str(registry.errors)])


func test_real_content_loads_without_errors() -> void:
	var registry := _real_registry()
	assert_eq(registry.errors, [] as Array[String], "Conteúdo real sem erros")
	assert_eq(registry.ids("class"), ["class.barbarian", "class.bard", "class.cleric", "class.druid",
			"class.fighter", "class.monk", "class.paladin", "class.ranger", "class.rogue", "class.sorcerer",
			"class.warlock", "class.wizard"] as Array[String], "As 12 classes do SRD 5.2.1")
	assert_eq(registry.ids("species"), ["species.dragonborn", "species.dwarf", "species.elf", "species.gnome",
			"species.goliath", "species.halfling", "species.human", "species.orc", "species.tiefling"] as Array[String],
			"As 9 espécies do SRD 5.2.1")
	assert_eq(registry.ids("background"), ["background.criminal", "background.soldier"] as Array[String], "Antecedentes")
	assert_true(registry.has("item", "item.chain_mail"), "Itens carregados")


func test_round_trip_of_valid_data_has_no_errors() -> void:
	var registry := ContentRegistry.new()
	assert_true(registry.load_from_dictionaries(_valid_data()), "Dados válidos em memória: %s" % str(registry.errors))


func test_integers_are_normalized() -> void:
	var registry := _real_registry()
	assert_true(registry.get_entry("class", "class.fighter")["hit_die"] is int, "hit_die normalizado para int")


func test_missing_required_field() -> void:
	var data := _valid_data()
	_find(data, "class", "class.fighter").erase("hit_die")
	_assert_error(data, "hit_die: campo obrigatório ausente", "Campo obrigatório")


func test_wrong_type() -> void:
	var data := _valid_data()
	_find(data, "class", "class.fighter")["hit_die"] = "dez"
	_assert_error(data, "esperado número inteiro", "Tipo errado")


func test_unknown_field() -> void:
	var data := _valid_data()
	_find(data, "species", "species.human")["asas"] = true
	_assert_error(data, "campo desconhecido 'asas'", "Campo desconhecido")


func test_invalid_enum_value() -> void:
	var data := _valid_data()
	_find(data, "species", "species.human")["size"] = "huge"
	_assert_error(data, "valor 'huge' inválido", "Enum")


func test_duplicate_id() -> void:
	var data := _valid_data()
	data["item"].append(_find(data, "item", "item.dagger").duplicate(true))
	_assert_error(data, "id duplicado", "Id duplicado")


func test_wrong_id_prefix() -> void:
	var data := _valid_data()
	_find(data, "item", "item.dagger")["id"] = "weapon.dagger"
	_assert_error(data, "deve começar com 'item.'", "Prefixo do id")


func test_broken_reference() -> void:
	var data := _valid_data()
	_find(data, "class", "class.rogue")["starting_armor"] = "item.mithril"
	_assert_error(data, "referência a item inexistente 'item.mithril'", "Referência quebrada")


func test_reference_of_wrong_item_type() -> void:
	var data := _valid_data()
	_find(data, "class", "class.rogue")["starting_weapons"] = ["item.leather_armor"]
	_assert_error(data, "deveria ser do tipo weapon", "Tipo de item errado")


func test_unknown_skill_and_ability() -> void:
	var data := _valid_data()
	_find(data, "background", "background.soldier")["skill_proficiencies"] = ["athletics", "flying"]
	_assert_error(data, "perícia desconhecida 'flying'", "Perícia desconhecida")
	data = _valid_data()
	_find(data, "class", "class.rogue")["saving_throws"] = ["dex", "luck"]
	_assert_error(data, "atributo desconhecido 'luck'", "Atributo desconhecido")


func test_invalid_dice_expression() -> void:
	var data := _valid_data()
	_find(data, "item", "item.longsword")["damage"] = "1d7"
	_assert_error(data, "d7 não suportado", "Dado inválido")


func test_class_armor_without_training() -> void:
	var data := _valid_data()
	_find(data, "class", "class.rogue")["starting_armor"] = "item.chain_mail"
	_assert_error(data, "exige treinamento que a classe não tem", "Armadura sem treinamento")


func test_invalid_suggested_scores() -> void:
	var data := _valid_data()
	_find(data, "class", "class.fighter")["suggested_scores"] = [15, 15, 14, 8, 12, 10]
	_assert_error(data, "suggested_scores", "Sugestão fora do arranjo padrão")


func test_class_data_matches_srd_level_1() -> void:
	var registry := _real_registry()
	# [dado de vida, resistências, nº de perícias, treinamento de armadura]
	var expected := {
		"class.barbarian": [12, ["str", "con"], 2, ["light", "medium", "shield"]],
		"class.bard": [8, ["dex", "cha"], 3, ["light"]],
		"class.cleric": [8, ["wis", "cha"], 2, ["light", "medium", "shield"]],
		"class.druid": [8, ["int", "wis"], 2, ["light", "shield"]],
		"class.fighter": [10, ["str", "con"], 2, ["light", "medium", "heavy", "shield"]],
		"class.monk": [8, ["str", "dex"], 2, []],
		"class.paladin": [10, ["wis", "cha"], 2, ["light", "medium", "heavy", "shield"]],
		"class.ranger": [10, ["str", "dex"], 3, ["light", "medium", "shield"]],
		"class.rogue": [8, ["dex", "int"], 4, ["light"]],
		"class.sorcerer": [6, ["con", "cha"], 2, []],
		"class.warlock": [8, ["wis", "cha"], 2, ["light"]],
		"class.wizard": [6, ["int", "wis"], 2, []],
	}
	for id: String in expected:
		var entry := registry.get_entry("class", id)
		var values: Array = expected[id]
		assert_eq(entry.get("hit_die"), values[0], "%s: dado de vida" % id)
		assert_eq(entry.get("saving_throws"), values[1], "%s: resistências" % id)
		assert_eq(entry.get("skill_choice_count"), values[2], "%s: perícias" % id)
		assert_eq(entry.get("armor_training"), values[3], "%s: treinamento de armadura" % id)
	assert_eq(registry.get_entry("class", "class.bard")["skill_options"].size(), 18, "Bardo escolhe entre todas as perícias")


func test_species_data_matches_srd() -> void:
	var registry := _real_registry()
	# [tamanho, deslocamento, visão no escuro]
	var expected := {
		"species.dragonborn": ["medium", 30, 60], "species.dwarf": ["medium", 30, 120],
		"species.elf": ["medium", 30, 60], "species.gnome": ["small", 30, 60],
		"species.goliath": ["medium", 35, 0], "species.halfling": ["small", 30, 0],
		"species.human": ["medium", 30, 0], "species.orc": ["medium", 30, 120],
		"species.tiefling": ["medium", 30, 60],
	}
	for id: String in expected:
		var entry := registry.get_entry("species", id)
		assert_eq([entry.get("size"), entry.get("speed"), entry.get("darkvision")], expected[id], "%s: tamanho, deslocamento, visão" % id)


func test_species_skill_options_consistency() -> void:
	var data := _valid_data()
	_find(data, "species", "species.elf")["extra_skill_choices"] = 4
	_assert_error(data, "extra_skill_choices maior que o número de opções", "Mais escolhas que opções")
	data = _valid_data()
	_find(data, "species", "species.elf")["extra_skill_choices"] = 0
	_assert_error(data, "extra_skill_options sem extra_skill_choices", "Opções sem escolha")


func test_monsters_and_encounters() -> void:
	var registry := _real_registry()
	assert_eq(registry.ids("monster"), ["monster.goblin_warrior", "monster.wolf"] as Array[String], "Monstros")
	assert_eq(registry.ids("encounter"), ["encounter.lone_wolf", "encounter.ruin_goblin"] as Array[String], "Encontros")
	var data := _valid_data()
	_find(data, "monster", "monster.wolf")["hit_points"] = 40
	_assert_error(data, "fora do intervalo de 2d8+2", "PV incompatíveis com os dados de vida")
	data = _valid_data()
	_find(data, "encounter", "encounter.lone_wolf")["enemies"] = [{"monster_id": "monster.dragon", "count": 1}]
	_assert_error(data, "referência a monster inexistente 'monster.dragon'", "Monstro inexistente no encontro")
	data = _valid_data()
	_find(data, "monster", "monster.goblin_warrior")["attacks"][1].erase("range_normal")
	_assert_error(data, "sem range_normal", "Ataque à distância sem alcance")
	data = _valid_data()
	_find(data, "monster", "monster.wolf")["sprite"] = "res://nada.png"
	_assert_error(data, "sprite inexistente", "Sprite ausente")


func test_versatile_weapon_requires_versatile_damage() -> void:
	var data := _valid_data()
	_find(data, "item", "item.longsword")["versatile_damage"] = ""
	_assert_error(data, "arma versátil sem versatile_damage", "Arma versátil")


func test_unsupported_schema_version_and_bad_json() -> void:
	var registry := ContentRegistry.new()
	var path := "user://test_content_bad"
	DirAccess.make_dir_recursive_absolute(path.path_join("items"))
	for sub in ["species", "classes", "backgrounds"]:
		DirAccess.make_dir_recursive_absolute(path.path_join(sub))
	var file := FileAccess.open(path.path_join("items/broken.json"), FileAccess.WRITE)
	file.store_string("{ \"schema_version\": 1, \"entries\": [ ")
	file.close()
	file = FileAccess.open(path.path_join("species/old.json"), FileAccess.WRITE)
	file.store_string("{ \"schema_version\": 99, \"entries\": [] }")
	file.close()
	assert_true(not registry.load_all(path), "Arquivos ruins devem falhar")
	assert_true(registry.errors.any(func(e: String) -> bool: return e.contains("JSON inválido")), "JSON inválido reportado com arquivo e linha")
	assert_true(registry.errors.any(func(e: String) -> bool: return e.contains("schema_version 99")), "Versão de esquema reportada")
	DirAccess.remove_absolute(path.path_join("items/broken.json"))
	DirAccess.remove_absolute(path.path_join("species/old.json"))
