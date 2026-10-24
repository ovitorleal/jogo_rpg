extends "res://tests/base_test.gd"
## Tela de criação: padrões válidos, bloqueio do botão com erros e coerência com a fábrica.

const SCENE := "res://scenes/menus/character_creation.tscn"

var _screen: Control


func _setup() -> void:
	_screen = (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(_screen)
	await tree.process_frame
	await tree.process_frame


func _teardown() -> void:
	_screen.queue_free()
	await tree.process_frame


func _start_button() -> Button:
	return _screen.get_node("%StartButton")


func _preview_text() -> String:
	return (_screen.get_node("%Preview") as CharacterSheetPanel).get_plain_text()


func test_defaults_produce_a_valid_character() -> void:
	await _setup()
	var c: CharacterData = _screen.get_character()
	assert_true(c != null, "Escolhas padrão devem ser válidas")
	assert_true(not _start_button().disabled, "Começar habilitado com personagem válido")
	if c != null:
		assert_eq(CharacterFactory.validate(c, Content.registry), [] as Array[String], "Personagem da tela passa na validação")
		assert_true(_preview_text().contains(c.name), "Prévia mostra o nome")
		assert_true(_preview_text().contains("CA"), "Prévia mostra a ficha")
	await _teardown()


func test_empty_name_disables_start_and_shows_error() -> void:
	await _setup()
	_screen.set_character_name("")
	assert_true(_screen.get_character() == null, "Sem nome, sem personagem")
	assert_true(_start_button().disabled, "Começar desabilitado")
	assert_true(_preview_text().contains("Informe um nome"), "Erro visível na prévia")
	_screen.set_character_name("Ilda")
	assert_true(_screen.get_character() != null and _screen.get_character().name == "Ilda", "Volta a ser válido")
	await _teardown()


func test_each_class_has_valid_defaults() -> void:
	await _setup()
	for class_id in Content.registry.ids("class"):
		_screen.select_class(class_id)
		await tree.process_frame
		var c: CharacterData = _screen.get_character()
		assert_true(c != null and c.class_id == class_id, "Padrões válidos para %s: %s" % [class_id, _preview_text()])
		if c != null and class_id == "class.rogue":
			assert_eq(c.expertise.size(), 2, "Ladino recebe duas especializações por padrão")
	await _teardown()


func test_choices_match_factory_result() -> void:
	await _setup()
	var choices: Dictionary = _screen.build_choices()
	var result := CharacterFactory.create(choices, Content.registry)
	assert_true(result[0] != null, "Escolhas da tela aceitas pela fábrica: %s" % str(result[1]))
	await _teardown()
