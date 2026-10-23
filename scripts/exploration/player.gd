class_name Player
extends CharacterBody2D
## Personagem controlado na exploração: movimento em 8 direções e detecção do
## objeto interativo mais próximo. A interação em si é acionada pelo mapa.

signal interaction_target_changed(target: Interactable)

const SPEED := 80.0

## Quando falso (ex.: mensagem aberta), o personagem não se move.
var input_enabled: bool = true:
	set(value):
		input_enabled = value
		if not value:
			velocity = Vector2.ZERO

var _target: Interactable = null

@onready var _sprite: Sprite2D = $Sprite
@onready var _detector: Area2D = $InteractionDetector


func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if input_enabled:
		direction = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = direction * SPEED
	if not is_zero_approx(direction.x):
		_sprite.flip_h = direction.x < 0.0
	move_and_slide()
	_update_target()


func get_interaction_target() -> Interactable:
	return _target


## Aciona o alvo atual. Retorna falso se não houver alvo ou se o controle estiver bloqueado.
func try_interact() -> bool:
	if not input_enabled or _target == null:
		return false
	_target.interact()
	return true


func _update_target() -> void:
	var nearest: Interactable = null
	var best_distance := INF
	for area in _detector.get_overlapping_areas():
		var candidate := area as Interactable
		if candidate == null or not candidate.enabled:
			continue
		var distance := _detector.global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = candidate
	if nearest != _target:
		_target = nearest
		interaction_target_changed.emit(_target)
