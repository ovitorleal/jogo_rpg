class_name ExplorationMap
extends Node2D
## Controlador de um mapa de exploração: limites da câmera, aviso de interação
## e mensagens. Espera os nós únicos %Ground, %Player e %Hud.

@onready var _ground: TileMapLayer = %Ground
@onready var _player: Player = %Player
@onready var _hud: ExplorationHud = %Hud


func _ready() -> void:
	_configure_camera_limits()
	_player.interaction_target_changed.connect(_on_interaction_target_changed)
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var interactable := node as Interactable
		if interactable != null and is_ancestor_of(interactable):
			interactable.interacted.connect(_on_interacted)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		handle_interact()


## Fecha a mensagem aberta ou, se não houver, aciona o objeto próximo ao jogador.
func handle_interact() -> void:
	if _hud.is_message_open():
		_hud.hide_message()
		_player.input_enabled = true
		_on_interaction_target_changed(_player.get_interaction_target())
		return
	_player.try_interact()


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
	if target == null or _hud.is_message_open():
		_hud.hide_prompt()
	else:
		_hud.show_prompt(target.prompt_text)


func _on_interacted(source: Interactable) -> void:
	if source.message_text.is_empty():
		return
	_player.input_enabled = false
	_hud.hide_prompt()
	_hud.show_message(source.message_text)
