class_name LevelUpEffect
extends Node2D
## Efeito de subida de nível no personagem do mapa: coluna de luz dourada, anel que se expande, faíscas
## subindo e um brilho no sprite. Some sozinho depois de DURATION segundos.

const DURATION := 1.8
const GOLD := Color(1.0, 0.84, 0.42)

var _time := 0.0
var _ring := 0.0
var _target: CanvasItem


## Cria o efeito como filho do personagem (pés na origem) e faz o sprite brilhar.
static func play_on(character: Node2D) -> LevelUpEffect:
	var effect := LevelUpEffect.new()
	effect.name = "LevelUpEffect"
	effect.z_index = 5
	character.add_child(effect)
	effect._target = character.get_node_or_null("Sprite") as CanvasItem
	return effect


func _ready() -> void:
	var sparks := CPUParticles2D.new()
	sparks.amount = 28
	sparks.lifetime = 1.1
	sparks.explosiveness = 0.15
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(9, 2)
	sparks.direction = Vector2.UP
	sparks.spread = 18.0
	sparks.gravity = Vector2(0, -20)
	sparks.initial_velocity_min = 18.0
	sparks.initial_velocity_max = 38.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.set_color(0, GOLD)
	fade.set_color(1, Color(1.0, 0.95, 0.7, 0.0))
	sparks.color_ramp = fade
	sparks.one_shot = true
	sparks.emitting = true
	add_child(sparks)
	if _target != null:
		var tween := create_tween()
		tween.tween_property(_target, "modulate", Color(1.8, 1.6, 1.0), 0.2)
		tween.tween_property(_target, "modulate", Color.WHITE, 0.6)


func _process(delta: float) -> void:
	_time += delta
	_ring = _time / DURATION
	queue_redraw()
	if _time >= DURATION:
		queue_free()


func _draw() -> void:
	var fade := clampf(1.0 - _ring, 0.0, 1.0)
	# Coluna de luz que sobe e se apaga.
	var height := 46.0 * minf(1.0, _ring * 3.0)
	draw_rect(Rect2(-9, -height, 18, height), Color(GOLD, 0.4 * fade))
	draw_rect(Rect2(-4, -height, 8, height), Color(1, 1, 0.9, 0.7 * fade))
	# Anel no chão que se expande.
	var radius := 4.0 + 16.0 * _ring
	draw_arc(Vector2(0, -1), radius, 0.0, TAU, 32, Color(GOLD, 0.8 * fade), 1.5)
