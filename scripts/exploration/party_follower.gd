class_name PartyFollower
extends Node2D
## Companheiro do grupo andando atrás do líder na exploração. Só apresentação: segue um ponto do
## rastro do jogador (dado pelo mapa) e anima parado/caminhada; não colide nem interage.

const SPEED := 96.0
## Distância (px) a partir da qual ele para de andar.
const STOP_DISTANCE := 2.0

var character: CharacterData
## Ponto do rastro que este seguidor tenta alcançar.
var target: Vector2
var facing: String = "down"

var _sprite: AnimatedSprite2D


func setup(c: CharacterData, start: Vector2) -> void:
	character = c
	global_position = start
	target = start
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
	refresh_appearance()


func refresh_appearance() -> void:
	if character == null or _sprite == null:
		return
	SpriteLibrary.attach(_sprite, SpriteLibrary.frames_for_texture(Appearance.key_for(character, Content.registry),
			Appearance.sheet_texture(character, Content.registry)))
	_sprite.animation = &""
	_play("idle")


func _physics_process(delta: float) -> void:
	var offset := target - global_position
	if offset.length() <= STOP_DISTANCE:
		_play("idle")
		return
	# Acelera quando fica muito para trás (ex.: o jogador correu numa reta longa).
	var speed := SPEED * (2.0 if offset.length() > 48.0 else 1.0)
	global_position = global_position.move_toward(target, speed * delta)
	facing = SpriteLibrary.direction_of(offset, facing)
	_play("walk")


func _play(action: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var anim := SpriteLibrary.animation_name(_sprite.sprite_frames, action, facing)
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
