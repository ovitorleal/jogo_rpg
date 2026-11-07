extends "res://tests/base_test.gd"
## Teclas numéricas (fila de cima e teclado numérico) escolhem a resposta do diálogo com o mesmo número.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")
const CLEARING := "res://scenes/world/test_map.tscn"

var exploration: Node
var party: Node
var quests: Node


func _begin() -> void:
	exploration = tree.root.get_node("ExplorationManager")
	party = tree.root.get_node("PartyManager")
	quests = tree.root.get_node("QuestManager")
	exploration.reset()
	quests.reset()
	exploration.scene_changes_enabled = false
	var hero: CharacterData = CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), tree.root.get_node("Content").registry)[0]
	party.start_new_party(hero)


func _end(map: Node) -> void:
	map.queue_free()
	await tree.process_frame
	exploration.scene_changes_enabled = true
	exploration.reset()
	quests.reset()
	party.clear()


func _open_amara() -> ExplorationMap:
	var map: ExplorationMap = (load(CLEARING) as PackedScene).instantiate()
	tree.root.add_child(map)
	await tree.process_frame
	(map.get_node("Objects/Amara") as Interactable).interact()
	await tree.process_frame
	return map


func _press(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await tree.process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await tree.process_frame


func test_number_row_picks_matching_answer() -> void:
	_begin()
	var map := await _open_amara()
	var hud: ExplorationHud = map.get_node("%Hud")
	assert_eq(hud.dialogue_options().size(), 3, "Amara oferece três respostas")
	var first_text := hud.get_message_text()
	await _press(KEY_1)
	assert_true(hud.get_message_text() != first_text, "Tecla 1 escolhe a primeira resposta")
	await _press(KEY_1)
	assert_true(not map.is_in_dialogue(), "Tecla 1 de novo aceita e encerra a conversa")
	assert_eq(quests.log.status("quest.ruin_threat"), QuestLog.Status.ACTIVE, "Missão aceita pelo teclado")
	await _end(map)


func test_numpad_picks_matching_answer() -> void:
	_begin()
	var map := await _open_amara()
	var hud: ExplorationHud = map.get_node("%Hud")
	var first_text := hud.get_message_text()
	await _press(KEY_KP_1)
	assert_true(hud.get_message_text() != first_text, "Teclado numérico 1 escolhe a primeira resposta")
	await _end(map)


func test_number_without_matching_answer_does_nothing() -> void:
	_begin()
	var map := await _open_amara()
	var hud: ExplorationHud = map.get_node("%Hud")
	var first_text := hud.get_message_text()
	await _press(KEY_9)
	assert_true(map.is_in_dialogue(), "Tecla sem resposta correspondente não fecha a conversa")
	assert_eq(hud.get_message_text(), first_text, "Tecla sem resposta correspondente não muda a fala")
	assert_eq(hud.dialogue_options().size(), 3, "As três respostas continuam lá")
	await _end(map)


func test_number_outside_dialogue_does_nothing() -> void:
	_begin()
	var map: ExplorationMap = (load(CLEARING) as PackedScene).instantiate()
	tree.root.add_child(map)
	await tree.process_frame
	await _press(KEY_1)
	assert_true(not map.is_in_dialogue(), "Fora de conversa, número não abre nem escolhe nada")
	assert_eq(quests.log.status("quest.ruin_threat"), QuestLog.Status.NOT_STARTED, "Nenhuma missão começa sozinha")
	await _end(map)
