class_name ExplorationMap
extends Node2D
## Controlador de um mapa de exploração: limites da câmera, aviso de interação,
## falas com retrato, ficha do personagem e início/retorno de encontros.
## Espera os nós únicos %Terrain (com a camada Ground), %Player e %Hud.

const NO_CHARACTER_MESSAGE := "Nenhum personagem no grupo. Use \"Novo jogo\" no menu para criar um."
const NO_CHARACTER_COMBAT_MESSAGE := "Algo se move entre as sombras... mas não há ninguém no grupo para lutar."
const PLAYER_PORTRAIT := preload("res://assets/portraits/hero_portrait.png")
const CONFIRM_HINT := "[E] Confirmar · [Esc] Cancelar"

## Ação aguardando confirmação (texto do Interactable.action).
var _pending_action: String = ""

@onready var _ground: TileMapLayer = %Terrain.get_node("Ground")
@onready var _player: Player = %Player
@onready var _hud: ExplorationHud = %Hud


func _ready() -> void:
	var back: Variant = ExplorationManager.take_return_position(scene_file_path)
	var entrance := ExplorationManager.take_entrance(scene_file_path)
	if back is Vector2:
		_player.global_position = back
		_player.reset_physics_interpolation()
	elif not entrance.is_empty() and has_node("Entrances/%s" % entrance):
		_player.global_position = (get_node("Entrances/%s" % entrance) as Node2D).global_position
		_player.reset_physics_interpolation()
	_configure_camera_limits()
	_player.interaction_target_changed.connect(_on_interaction_target_changed)
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var interactable := node as Interactable
		if interactable != null and is_ancestor_of(interactable):
			interactable.interacted.connect(_on_interacted)
	for node in get_tree().get_nodes_in_group(EncounterTrigger.GROUP):
		var trigger := node as EncounterTrigger
		if trigger != null and is_ancestor_of(trigger) and not trigger.is_queued_for_deletion():
			trigger.triggered.connect(_on_encounter_triggered)
	var message := ExplorationManager.take_return_message()
	if not message.is_empty():
		_show_player_line(message)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"character_sheet"):
		get_viewport().set_input_as_handled()
		toggle_character_sheet()
	elif event.is_action_pressed(&"ui_cancel") and _hud.is_sheet_open():
		get_viewport().set_input_as_handled()
		toggle_character_sheet()
	elif event.is_action_pressed(&"ui_cancel") and _hud.is_message_open():
		get_viewport().set_input_as_handled()
		cancel_message()
	elif event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		handle_interact()


## Fecha a mensagem aberta ou, se não houver, aciona o objeto próximo ao jogador.
## Com a ficha aberta, não faz nada.
func handle_interact() -> void:
	if _hud.is_sheet_open():
		return
	if _hud.is_message_open():
		var action := _pending_action
		_pending_action = ""
		_hud.hide_message()
		_player.input_enabled = true
		_on_interaction_target_changed(_player.get_interaction_target())
		if not action.is_empty():
			_execute_action(action)
		return
	_player.try_interact()


## Fecha a mensagem sem executar a ação pendente.
func cancel_message() -> void:
	_pending_action = ""
	_hud.hide_message()
	_player.input_enabled = true
	_on_interaction_target_changed(_player.get_interaction_target())


## Abre ou fecha a ficha do líder do grupo. Não abre por cima de uma mensagem.
func toggle_character_sheet() -> void:
	if _hud.is_sheet_open():
		_hud.hide_sheet()
		_player.input_enabled = true
		_on_interaction_target_changed(_player.get_interaction_target())
		return
	if _hud.is_message_open():
		return
	var leader: CharacterData = PartyManager.get_leader()
	_player.input_enabled = false
	_hud.hide_prompt()
	if leader == null:
		_hud.show_message(NO_CHARACTER_MESSAGE)
		return
	_hud.show_sheet(CharacterSheet.build(leader, Content.registry))


## Área do mapa em pixels, a partir dos tiles usados.
func get_map_rect() -> Rect2i:
	var used := _ground.get_used_rect()
	var tile_size := _ground.tile_set.tile_size
	return Rect2i(used.position * tile_size, used.size * tile_size)


func _configure_camera_limits() -> void:
	var camera := _player.get_node("Camera") as Camera2D
	var rect := get_map_rect()
	camera.limit_left = rect.position.x
	camera.limit_top = rect.position.y
	camera.limit_right = rect.end.x
	camera.limit_bottom = rect.end.y


func _on_interaction_target_changed(target: Interactable) -> void:
	if target == null or _hud.is_message_open() or _hud.is_sheet_open():
		_hud.hide_prompt()
	else:
		_hud.show_prompt(target.prompt_text)


func _on_interacted(source: Interactable) -> void:
	if source.message_text.is_empty():
		return
	if not source.action.is_empty():
		_pending_action = source.action
		_player.input_enabled = false
		_hud.hide_prompt()
		var leader: CharacterData = PartyManager.get_leader()
		_hud.show_message(source.message_text, leader.name if leader != null else "",
				PLAYER_PORTRAIT if leader != null else null, CONFIRM_HINT)
		return
	if source.speaker_name.is_empty() and source.speaker_portrait == null:
		_show_player_line(source.message_text)
	else:
		_player.input_enabled = false
		_hud.hide_prompt()
		_hud.show_message(source.message_text, source.speaker_name, source.speaker_portrait)


## Fala do personagem do jogador, com nome e retrato em destaque (sem grupo, mensagem simples).
func _show_player_line(text: String) -> void:
	var leader: CharacterData = PartyManager.get_leader()
	_player.input_enabled = false
	_hud.hide_prompt()
	if leader == null:
		_hud.show_message(text)
	else:
		_hud.show_message(text, leader.name, PLAYER_PORTRAIT)


func _execute_action(action: String) -> void:
	if not PartyManager.has_party():
		_show_player_line(NO_CHARACTER_MESSAGE)
		return
	if action.begins_with("travel:"):
		_player.input_enabled = false
		ExplorationManager.begin_travel.call_deferred(action.trim_prefix("travel:"))
	elif action == "rest_long":
		var healed := 0
		for c in PartyManager.members:
			healed += Rest.long_rest(c, Content.registry)
		_show_player_line("Você descansa junto à fogueira até o amanhecer. PV e Dados de Vida restaurados (+%d PV)." % healed)
	else:
		push_error("Ação desconhecida: %s" % action)


func _on_encounter_triggered(trigger: EncounterTrigger) -> void:
	var leader: CharacterData = PartyManager.get_leader()
	if leader == null or leader.current_hp <= 0:
		_player.input_enabled = false
		_hud.hide_prompt()
		_hud.show_message(NO_CHARACTER_COMBAT_MESSAGE)
		return
	_player.input_enabled = false
	# Adiado: o sinal vem de um callback de física, onde não se pode remover a cena atual.
	ExplorationManager.begin_encounter.call_deferred(trigger.encounter_id, trigger.trigger_id, scene_file_path,
			_player.global_position)
