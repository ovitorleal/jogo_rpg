extends "res://tests/base_test.gd"
## Critérios da Fase 1: andar pelo mapa, colidir com obstáculos, interagir com um objeto
## e câmera limitada ao mapa. Usa o mapa de teste real e a física do motor.

const MAP_SCENE := "res://scenes/world/test_map.tscn"
const TILE := 16

var _map: ExplorationMap
var _player: Player
var _hud: ExplorationHud
var _ground: TileMapLayer


func _setup() -> void:
	_map = (load(MAP_SCENE) as PackedScene).instantiate()
	tree.root.add_child(_map)
	_player = _map.get_node("%Player")
	_hud = _map.get_node("%Hud")
	_ground = _map.get_node("%Ground")
	await _physics_frames(2)


func _teardown() -> void:
	for action in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(action)
	_map.queue_free()
	await tree.process_frame


func _physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _physics_frames(frames)
	Input.action_release(action)
	await _physics_frames(1)


func _teleport(position: Vector2) -> void:
	_player.global_position = position
	_player.reset_physics_interpolation()
	await _physics_frames(2)


func test_player_moves_with_input() -> void:
	await _setup()
	var start := _player.global_position
	await _hold(&"move_right", 20)
	assert_true(_player.global_position.x > start.x + 10.0,
			"Jogador deve andar para a direita (de %s para %s)" % [start, _player.global_position])
	var after_right := _player.global_position
	await _hold(&"move_up", 20)
	assert_true(_player.global_position.y < after_right.y - 10.0, "Jogador deve andar para cima")
	await _teardown()


func test_diagonal_speed_is_normalized() -> void:
	await _setup()
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	await _physics_frames(2)
	assert_true(_player.velocity.length() > 0.0, "Jogador deve se mover na diagonal")
	assert_true(_player.velocity.length() <= Player.SPEED + 0.01,
			"Velocidade diagonal não deve exceder SPEED (%.2f)" % _player.velocity.length())
	await _teardown()


func test_wall_blocks_movement() -> void:
	await _setup()
	# Estrada leste-oeste (linha 16), junto ao muro da borda oeste (coluna 0).
	await _teleport(Vector2(TILE + 12, 16 * TILE + 8))
	await _hold(&"move_left", 40)
	assert_true(_player.global_position.x >= TILE, "Muro deve impedir a passagem (x = %.1f)" % _player.global_position.x)
	assert_true(_player.global_position.x < TILE + 12, "Jogador deve ter andado até encostar no muro")
	await _teardown()


func test_water_blocks_movement() -> void:
	await _setup()
	# Areia ao sul do lago (lago ocupa tiles x 8..15, y 5..9).
	await _teleport(Vector2(11 * TILE + 8, 10 * TILE + 14))
	await _hold(&"move_up", 40)
	assert_true(_player.global_position.y >= 10 * TILE, "Água deve impedir a passagem (y = %.1f)" % _player.global_position.y)
	await _teardown()


func test_sign_interaction_shows_message_and_blocks_movement() -> void:
	await _setup()
	var sign: Interactable = _map.get_node("Objects/WelcomeSign")
	assert_true(_player.get_interaction_target() == null, "Sem alvo no início")
	assert_true(not _hud.is_prompt_visible(), "Sem aviso no início")

	await _teleport(sign.global_position + Vector2(0, 14))
	assert_true(_player.get_interaction_target() == sign, "Placa deve ser o alvo quando o jogador está perto")
	assert_true(_hud.is_prompt_visible(), "Aviso de interação deve aparecer")

	_map.handle_interact()
	assert_true(_hud.is_message_open(), "Mensagem deve abrir")
	assert_eq(_hud.get_message_text(), sign.message_text, "Texto da mensagem")
	assert_true(not _hud.is_prompt_visible(), "Aviso deve sumir com a mensagem aberta")

	var frozen_at := _player.global_position
	await _hold(&"move_down", 15)
	assert_eq(_player.global_position, frozen_at, "Jogador não deve andar com a mensagem aberta")

	_map.handle_interact()
	assert_true(not _hud.is_message_open(), "Segunda interação deve fechar a mensagem")
	assert_true(_player.input_enabled, "Controle deve voltar após fechar")
	assert_true(_hud.is_prompt_visible(), "Aviso deve voltar se ainda estiver perto")
	await _teardown()


func test_interact_input_event_reaches_map() -> void:
	await _setup()
	var sign: Interactable = _map.get_node("Objects/WelcomeSign")
	await _teleport(sign.global_position + Vector2(0, 14))
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	await tree.process_frame
	assert_true(_hud.is_message_open(), "Tecla de interação deve abrir a mensagem")
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await tree.process_frame
	await _teardown()


func test_interact_without_target_does_nothing() -> void:
	await _setup()
	_map.handle_interact()
	assert_true(not _hud.is_message_open(), "Sem alvo, nenhuma mensagem deve abrir")
	assert_true(_player.input_enabled, "Controle continua liberado")
	await _teardown()


func test_camera_limits_match_map() -> void:
	await _setup()
	var camera: Camera2D = _player.get_node("Camera")
	var rect := _map.get_map_rect()
	assert_eq(rect, Rect2i(0, 0, 60 * TILE, 34 * TILE), "Área do mapa")
	assert_eq(camera.limit_left, 0, "Limite esquerdo")
	assert_eq(camera.limit_top, 0, "Limite superior")
	assert_eq(camera.limit_right, rect.end.x, "Limite direito")
	assert_eq(camera.limit_bottom, rect.end.y, "Limite inferior")
	assert_true(camera.is_current(), "Câmera do jogador deve estar ativa")
	await _teardown()


func test_map_border_is_closed_and_spawn_is_walkable() -> void:
	await _setup()
	var used := _ground.get_used_rect()
	for x in range(used.position.x, used.end.x):
		for y in [used.position.y, used.end.y - 1]:
			assert_true(_is_blocking(Vector2i(x, y)), "Borda aberta em (%d, %d)" % [x, y])
	for y in range(used.position.y, used.end.y):
		for x in [used.position.x, used.end.x - 1]:
			assert_true(_is_blocking(Vector2i(x, y)), "Borda aberta em (%d, %d)" % [x, y])
	var spawn_cell := _ground.local_to_map(_ground.to_local(_player.global_position))
	assert_true(not _is_blocking(spawn_cell), "Ponto inicial do jogador deve ser caminhável")
	await _teardown()


func test_sign_line_shows_player_portrait_and_name() -> void:
	var party: Node = tree.root.get_node("PartyManager")
	var factory_tests: Object = load("res://tests/characters/test_character_factory.gd").new()
	var registry: ContentRegistry = tree.root.get_node("Content").registry
	var hero: CharacterData = CharacterFactory.create(factory_tests.fighter_choices(), registry)[0]
	party.start_new_party(hero)
	await _setup()
	var sign: Interactable = _map.get_node("Objects/WelcomeSign")
	await _teleport(sign.global_position + Vector2(0, 14))
	_map.handle_interact()
	assert_true(_hud.is_message_open(), "Fala abre")
	assert_eq(_hud.get_speaker_name(), hero.name, "Nome do personagem em destaque")
	assert_true(_hud.get_portrait() != null, "Retrato do personagem ao lado da fala")
	assert_true(_hud.get_message_text().contains("A placa diz"), "Personagem lê a placa em voz alta")
	_map.handle_interact()
	party.clear()
	await _teardown()


func test_line_without_party_has_no_portrait() -> void:
	tree.root.get_node("PartyManager").clear()
	await _setup()
	var sign: Interactable = _map.get_node("Objects/WelcomeSign")
	await _teleport(sign.global_position + Vector2(0, 14))
	_map.handle_interact()
	assert_true(_hud.is_message_open(), "Mensagem abre mesmo sem grupo")
	assert_true(_hud.get_portrait() == null and _hud.get_speaker_name().is_empty(), "Sem grupo: mensagem simples")
	await _teardown()


func test_character_sheet_toggle() -> void:
	var party: Node = tree.root.get_node("PartyManager")
	var factory_tests: Object = load("res://tests/characters/test_character_factory.gd").new()
	var registry: ContentRegistry = tree.root.get_node("Content").registry
	var hero: CharacterData = CharacterFactory.create(factory_tests.fighter_choices(), registry)[0]
	party.start_new_party(hero)
	await _setup()

	_map.toggle_character_sheet()
	assert_true(_hud.is_sheet_open(), "Ficha abre")
	assert_true(_hud.get_sheet_text().contains(hero.name), "Ficha mostra o líder do grupo")
	assert_true(_hud.get_sheet_text().contains("Guerreiro"), "Ficha mostra a classe")
	assert_true(not _player.input_enabled, "Jogador parado com a ficha aberta")
	var frozen_at := _player.global_position
	await _hold(&"move_right", 10)
	assert_eq(_player.global_position, frozen_at, "Não anda com a ficha aberta")
	_map.handle_interact()
	assert_true(not _hud.is_message_open(), "Interação ignorada com a ficha aberta")

	_map.toggle_character_sheet()
	assert_true(not _hud.is_sheet_open(), "Ficha fecha")
	assert_true(_player.input_enabled, "Controle volta")
	party.clear()
	await _teardown()


func test_character_sheet_without_party_shows_message() -> void:
	tree.root.get_node("PartyManager").clear()
	await _setup()
	_map.toggle_character_sheet()
	assert_true(not _hud.is_sheet_open(), "Sem grupo, não abre ficha")
	assert_true(_hud.is_message_open() and _hud.get_message_text().contains("Nenhum personagem"), "Explica o motivo")
	_map.handle_interact()
	assert_true(not _hud.is_message_open() and _player.input_enabled, "Mensagem fecha normalmente")
	await _teardown()


func _is_blocking(cell: Vector2i) -> bool:
	var data := _ground.get_cell_tile_data(cell)
	return data != null and data.get_collision_polygons_count(0) > 0
