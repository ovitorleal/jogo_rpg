extends "res://tests/base_test.gd"
## O personagem pode ser salvo e carregado sem perda e sem aceitar dados incoerentes.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")
const SAVE_PATH := "user://test_character.json"

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


func _make(rogue: bool = false) -> CharacterData:
	var fixtures := FACTORY_TESTS.new()
	var choices: Dictionary = fixtures.rogue_choices() if rogue else fixtures.fighter_choices()
	return CharacterFactory.create(choices, _registry())[0]


func _reload(data: Dictionary) -> Array:
	return CharacterData.from_dict(JSON.parse_string(JSON.stringify(data)))


func test_round_trip_through_json_preserves_everything() -> void:
	for rogue in [false, true]:
		var original := _make(rogue)
		var result := _reload(original.to_dict())
		var loaded: CharacterData = result[0]
		assert_true(loaded != null, "Carregou: %s" % str(result[1]))
		if loaded == null:
			continue
		assert_eq(loaded.to_dict(), original.to_dict(), "Dados idênticos após ida e volta")
		assert_eq(CharacterFactory.validate(loaded, _registry()), [] as Array[String], "Personagem carregado é válido")
		var a := CharacterSheet.build(original, _registry())
		var b := CharacterSheet.build(loaded, _registry())
		assert_eq([b.armor_class, b.max_hp, b.skills, b.saving_throws], [a.armor_class, a.max_hp, a.skills, a.saving_throws],
				"Ficha derivada igual")


func test_save_and_load_file() -> void:
	var original := _make(true)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert_true(file != null, "Abrir %s para escrita" % SAVE_PATH)
	if file == null:
		return
	file.store_string(JSON.stringify(original.to_dict(), "\t"))
	file.close()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	assert_true(parsed is Dictionary, "Arquivo salvo é JSON válido")
	var loaded: CharacterData = CharacterData.from_dict(parsed)[0]
	assert_true(loaded != null and loaded.to_dict() == original.to_dict(), "Arquivo carregado igual ao original")
	DirAccess.remove_absolute(SAVE_PATH)


func test_rejects_wrong_schema_version() -> void:
	var data := _make().to_dict()
	data["schema_version"] = 2
	var result := CharacterData.from_dict(data)
	assert_true(result[0] == null and str(result[1]).contains("Versão de esquema"), "Versão desconhecida rejeitada")


func test_rejects_missing_and_mistyped_fields() -> void:
	var data := _make().to_dict()
	data.erase("class_id")
	assert_true(CharacterData.from_dict(data)[0] == null, "Campo ausente rejeitado")
	data = _make().to_dict()
	data["level"] = "um"
	assert_true(CharacterData.from_dict(data)[0] == null, "Nível não numérico rejeitado")
	data = _make().to_dict()
	data["base_scores"]["luck"] = 10
	assert_true(CharacterData.from_dict(data)[0] == null, "Atributo desconhecido rejeitado")
	data = _make().to_dict()
	data["poderes"] = []
	assert_true(CharacterData.from_dict(data)[0] == null, "Campo desconhecido rejeitado")


func test_tampered_values_fail_validation() -> void:
	var data := _make().to_dict()
	data["current_hp"] = 999
	var loaded: CharacterData = _reload(data)[0]
	assert_true(str(CharacterFactory.validate(loaded, _registry())).contains("PV atuais"), "PV acima do máximo")
	data = _make().to_dict()
	data["base_scores"] = {"str": 15, "dex": 15, "con": 15, "int": 15, "wis": 15, "cha": 15}
	loaded = _reload(data)[0]
	assert_true(str(CharacterFactory.validate(loaded, _registry())).contains("Arranjo padrão"), "Atributos adulterados")
	data = _make().to_dict()
	data["class_id"] = "class.necromancer"
	loaded = _reload(data)[0]
	assert_true(str(CharacterFactory.validate(loaded, _registry())).contains("Classe desconhecida"), "Classe inexistente")


func test_party_manager_keeps_leader() -> void:
	var party: Node = tree.root.get_node("PartyManager")
	var c := _make()
	party.start_new_party(c)
	assert_true(party.has_party() and party.get_leader() == c, "Líder do grupo")
	party.clear()
	assert_true(not party.has_party() and party.get_leader() == null, "Grupo vazio após limpar")
