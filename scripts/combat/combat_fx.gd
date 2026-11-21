class_name CombatFx
extends RefCounted
## Efeitos do combate (só apresentação): tremor de tela, faíscas de impacto, poeira de queda, desfazer em partículas
## e cor dos números de dano por tipo. Usa CPUParticles2D, que funciona no renderizador Compatibility (Web).

## Cor do número de dano por tipo (SRD 5.2.1); físico e desconhecido em branco quente.
const DAMAGE_COLORS := {
	"fire": Color8(255, 140, 60), "cold": Color8(140, 210, 255), "lightning": Color8(255, 236, 110),
	"thunder": Color8(170, 160, 255), "acid": Color8(170, 240, 90), "poison": Color8(110, 220, 110),
	"radiant": Color8(255, 246, 190), "necrotic": Color8(190, 150, 220), "psychic": Color8(255, 140, 210),
	"force": Color8(200, 160, 255),
}
const PHYSICAL_COLOR := Color8(255, 240, 230)
const SPARK_COLOR := Color8(255, 226, 150)
const DUST_COLOR := Color8(170, 150, 120)


static func damage_color(damage_type: String) -> Color:
	return DAMAGE_COLORS.get(damage_type, PHYSICAL_COLOR)


## Tremor curto do nó (a tela do combate). Desligado nas opções: não faz nada e devolve false.
static func shake(node: CanvasItem, strength: float, enabled: bool, duration: float = 0.25) -> bool:
	if not enabled or node == null or not node.is_inside_tree():
		return false
	if node.has_meta("shake_home"):
		return true # já tremendo: não acumula deslocamento
	var home: Vector2 = node.get("position")
	node.set_meta("shake_home", home)
	var tween := node.create_tween()
	var steps := maxi(3, int(duration / 0.04))
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		tween.tween_property(node, "position", home + offset.round(), duration / steps)
	tween.tween_property(node, "position", home, 0.03)
	tween.tween_callback(func() -> void: node.remove_meta("shake_home"))
	return true


## Rajada de partículas que some sozinha. kind: "spark" (impacto), "dust" (queda), "dissolve" (inimigo morto).
static func burst(parent: Node, at: Vector2, color: Color, kind: String = "spark") -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.z_index = 90
	p.color = color
	match kind:
		"dust":
			p.amount = 10
			p.lifetime = 0.5
			p.direction = Vector2(0, -1)
			p.spread = 80.0
			p.gravity = Vector2(0, 40)
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 22.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.0
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(8, 1)
		"dissolve":
			p.amount = 28
			p.lifetime = 0.8
			p.direction = Vector2(0, -1)
			p.spread = 40.0
			p.gravity = Vector2(0, -30)
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 24.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(6, 10)
		_:
			p.amount = 9
			p.lifetime = 0.3
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.gravity = Vector2(0, 160)
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 70.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p
