class_name Player
extends CharacterBody2D
## Personagem controlado na exploração: movimento em 8 direções, animação de caminhada em
## 4 direções e detecção do objeto interativo mais próximo. A interação é acionada pelo mapa.

signal interaction_target_changed(target: Interactable)

const SPEED := 80.0
const SHEET := "res://assets/characters/hero_sheet.png"

## Quando falso (ex.: mensagem aberta), o personagem não se move.
var input_enabled: bool = true:
	set(value):
		input_enabled = value
		if not value:
			velocity = Vector2.ZERO

var facing: String = "down"

var _target: Interactable = null

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _detector: Area2D = $InteractionDetector


func _ready() -> void:
	_sprite.sprite_frames = SpriteLibrary.frames_for(SHEET)
	_sprite.offset = SpriteLibrary.FEET_OFFSET
	_play("idle")


func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if input_enabled:
		direction = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = direction * SPEED
	move_and_slide()
	if direction != Vector2.ZERO:
		facing = SpriteLibrary.direction_of(direction, facing)
		_play("walk")
	else:
		_play("idle")
	_update_target()


func get_interaction_target() -> Interactable:
	return _target


func get_current_animation() -> StringName:
	return _sprite.animation


## Aciona o alvo atual. Retorna falso se não houver alvo ou se o controle estiver bloqueado.
func try_interact() -> bool:
	if not input_enabled or _target == null:
		return false
	_target.interact()
	return true


func _play(action: String) -> void:
	var anim := SpriteLibrary.animation_name(_sprite.sprite_frames, action, facing)
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


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
