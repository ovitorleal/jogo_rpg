class_name SpellVfx
extends Node2D
## Efeitos visuais das magias no tabuleiro de combate (só apresentação; o resultado já foi
## resolvido pelo CombatManager). Desenhados por código em pixels de 1 unidade do tabuleiro,
## no mesmo estilo 16 bits dos sprites: núcleo claro, cor da magia, brilho e faíscas.
##
## Estilos (campo "vfx" da magia): bolt, ray, darts, pillar, spray, mock, cone, wave, heal, aura, mark.
## Uso: var fx := SpellVfx.create(...); board.add_child(fx); await fx.finished

signal finished

const DURATIONS := {
	"bolt": 0.62, "ray": 0.5, "darts": 0.8, "pillar": 0.7, "spray": 0.65, "mock": 0.7,
	"cone": 0.75, "wave": 0.6, "heal": 0.8, "aura": 0.8, "mark": 0.8,
}
const OUTLINE := Color8(26, 16, 32)

var style: String = "bolt"
var color: Color = Color.WHITE
var origin := Vector2.ZERO
var targets: Array[Vector2] = []
## Retângulos das casas atingidas (cone/cubo), em coordenadas do tabuleiro.
var area: Array[Rect2] = []
var darts: int = 3
var duration: float = 0.6
var _t: float = 0.0
var _done := false


static func create(vfx_style: String, vfx_color: Color, from: Vector2, to: Array[Vector2], cells: Array[Rect2],
		dart_count: int = 3) -> SpellVfx:
	var fx := SpellVfx.new()
	fx.style = vfx_style
	fx.color = vfx_color
	fx.origin = from
	fx.targets = to
	fx.area = cells
	fx.darts = maxi(1, dart_count)
	fx.duration = float(DURATIONS.get(vfx_style, 0.6))
	fx.z_index = 200
	return fx


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= duration and not _done:
		_done = true
		finished.emit()
		queue_free()


## Progresso 0..1 de um trecho [a, b] da animação.
func _phase(a: float, b: float) -> float:
	return clampf((_t / duration - a) / maxf(0.001, b - a), 0.0, 1.0)


func _draw() -> void:
	match style:
		"bolt":
			_draw_bolt()
		"ray":
			_draw_ray()
		"darts":
			_draw_darts()
		"pillar":
			_draw_pillar()
		"spray":
			_draw_spray()
		"mock":
			_draw_mock()
		"cone":
			_draw_cone()
		"wave":
			_draw_wave()
		"heal":
			_draw_heal()
		"aura":
			_draw_aura()
		"mark":
			_draw_mark()


# --- Primitivas em "pixels" ---------------------------------------------------

func _px(at: Vector2, size: float, c: Color) -> void:
	var s := maxf(1.0, roundf(size))
	draw_rect(Rect2((at - Vector2(s, s) * 0.5).round(), Vector2(s, s)), c)


## Disco pixelado com halo, núcleo claro e borda escura.
func _orb(at: Vector2, radius: float, c: Color, alpha: float = 1.0) -> void:
	var r := maxf(1.0, radius)
	draw_circle(at.round(), r * 2.4, Color(c, 0.18 * alpha))
	draw_circle(at.round(), r * 1.6, Color(c, 0.22 * alpha))
	draw_circle(at.round(), r + 1.0, Color(OUTLINE, 0.55 * alpha))
	draw_circle(at.round(), r, Color(c, alpha))
	draw_circle((at + Vector2(-r * 0.3, -r * 0.3)).round(), maxf(1.0, r * 0.5), Color(c.lightened(0.6), alpha))


## Anel pixelado (contorno de pontos).
func _ring(at: Vector2, radius: float, c: Color, alpha: float, thickness: float = 1.0) -> void:
	var steps := maxi(12, int(radius * 2.5))
	for i in steps:
		var a := TAU * i / steps
		_px(at + Vector2(cos(a), sin(a)) * radius, thickness, Color(c, alpha))


func _sparks(at: Vector2, count: int, spread: float, progress: float, c: Color, seed_value: int = 0) -> void:
	for i in count:
		var a := _hash(i + seed_value) * TAU
		var speed := 0.5 + _hash(i * 7 + 3 + seed_value) * 0.5
		var p := at + Vector2(cos(a), sin(a)) * spread * progress * speed
		var fade := 1.0 - progress
		_px(p, 2.0 if i % 3 == 0 else 1.0, Color(c.lightened(0.3 * fade), fade))


func _impact(at: Vector2, progress: float, c: Color, size: float = 10.0) -> void:
	if progress <= 0.0 or progress >= 1.0:
		return
	_ring(at, 2.0 + size * progress, c, 1.0 - progress, 2.0)
	_orb(at, maxf(1.0, (size * 0.5) * (1.0 - progress)), c.lightened(0.3), 1.0 - progress)
	_sparks(at, 10, size * 1.4, progress, c)


static func _hash(n: int) -> float:
	var x := (n * 1103515245 + 12345) & 0x7fffffff
	return float(x % 1000) / 1000.0


func _first_target() -> Vector2:
	return targets[0] if not targets.is_empty() else origin + Vector2(32, 0)


# --- Estilos --------------------------------------------------------------------

func _draw_bolt() -> void:
	var to := _first_target()
	var travel := _phase(0.0, 0.55)
	if travel < 1.0:
		var head := origin.lerp(to, travel)
		for i in 12:
			var back := clampf(travel - i * 0.03, 0.0, 1.0)
			var p := origin.lerp(to, back) + Vector2(0, sin((back + i) * 9.0) * 1.5)
			_px(p, 5.0 - i * 0.35, Color(color.lightened(0.2 if i < 3 else 0.0), 0.9 - i * 0.07))
		_orb(head, 4.5, color)
	_impact(to, _phase(0.5, 1.0), color, 16.0)


func _draw_ray() -> void:
	var to := _first_target()
	var grow := _phase(0.0, 0.18)
	var fade := 1.0 - _phase(0.6, 1.0)
	var end := origin.lerp(to, grow)
	var flicker := 1.0 + 0.5 * sin(_t * 70.0)
	draw_line(origin.round(), end.round(), Color(OUTLINE, 0.5 * fade), 5.0 * flicker)
	draw_line(origin.round(), end.round(), Color(color, fade), 3.0 * flicker)
	draw_line(origin.round(), end.round(), Color(color.lightened(0.7), fade), 1.0)
	# Partículas que correm pelo feixe.
	for i in 6:
		var k := fmod(_t * 3.0 + i / 6.0, 1.0) * grow
		_px(origin.lerp(to, k) + Vector2(0, (_hash(i) - 0.5) * 4.0), 1.0, Color(color.lightened(0.5), fade))
	_orb(origin, 2.5 * fade, color, fade)
	if grow >= 1.0:
		_impact(to, _phase(0.18, 0.9), color, 10.0)


func _draw_darts() -> void:
	var to := _first_target()
	var normal := (to - origin).orthogonal().normalized()
	for i in darts:
		var start := 0.08 * i
		var travel := _phase(start, start + 0.55)
		var spread := (i - (darts - 1) / 2.0) * 14.0
		var control := origin.lerp(to, 0.5) + normal * spread
		if travel > 0.0 and travel < 1.0:
			for j in 7:
				var k := clampf(travel - j * 0.035, 0.0, 1.0)
				_px(_bezier(origin, control, to, k), 3.0 - j * 0.35, Color(color, 0.9 - j * 0.12))
			_orb(_bezier(origin, control, to, travel), 3.0, color)
		_impact(to + Vector2(spread * 0.15, 0), _phase(start + 0.55, start + 0.85), color, 10.0)


static func _bezier(a: Vector2, b: Vector2, c: Vector2, k: float) -> Vector2:
	return a.lerp(b, k).lerp(b.lerp(c, k), k)


func _draw_pillar() -> void:
	for to in targets:
		var drop := _phase(0.0, 0.25)
		var fade := 1.0 - _phase(0.65, 1.0)
		var top := to + Vector2(0, -90)
		var bottom := top.lerp(to + Vector2(0, 4), drop)
		var width := 8.0 + 2.0 * sin(_t * 40.0)
		draw_rect(Rect2(Vector2(to.x - width * 0.5 - 1.0, top.y), Vector2(width + 2.0, bottom.y - top.y)).abs(), Color(OUTLINE, 0.35 * fade))
		draw_rect(Rect2(Vector2(to.x - width * 0.5, top.y), Vector2(width, bottom.y - top.y)).abs(), Color(color, 0.75 * fade))
		draw_rect(Rect2(Vector2(to.x - 1.5, top.y), Vector2(3.0, bottom.y - top.y)).abs(), Color(color.lightened(0.7), fade))
		if drop >= 1.0:
			_ring(to + Vector2(0, 2), 4.0 + 10.0 * _phase(0.25, 0.8), color, fade, 2.0)
			for i in 8:
				var k := fmod(_t * 1.5 + _hash(i), 1.0)
				_px(to + Vector2((_hash(i + 9) - 0.5) * 16.0, -k * 28.0), 1.0, Color(color.lightened(0.5), fade * (1.0 - k)))


func _draw_spray() -> void:
	var to := _first_target()
	for i in 9:
		var start := 0.05 * i
		var k := _phase(start, start + 0.5)
		if k <= 0.0 or k >= 1.0:
			continue
		var p := origin.lerp(to, k) + Vector2((_hash(i) - 0.5) * 10.0 * k, (_hash(i + 5) - 0.5) * 10.0 * k)
		var r := 2.0 + 5.0 * k
		_orb(p, r, color if i % 2 == 0 else color.darkened(0.25), 0.85 * (1.0 - k * 0.6))
	var cloud := _phase(0.45, 1.0)
	if cloud > 0.0 and cloud < 1.0:
		for i in 5:
			var a := TAU * i / 5.0 + _t * 2.0
			_orb(to + Vector2(cos(a), sin(a)) * (6.0 + 6.0 * cloud), 4.0 * (1.0 - cloud) + 1.0, color, 1.0 - cloud)


func _draw_mock() -> void:
	var to := _first_target()
	var dir := (to - origin).normalized()
	for i in 4:
		var k := _phase(0.08 * i, 0.08 * i + 0.6)
		if k <= 0.0 or k >= 1.0:
			continue
		var center := origin.lerp(to, k)
		var r := 4.0 + 6.0 * k
		for j in 7:
			var a := dir.angle() + lerpf(-0.9, 0.9, j / 6.0)
			_px(center + Vector2(cos(a), sin(a)) * r, 2.0, Color(color, 1.0 - k * 0.5))
	var hit := _phase(0.6, 1.0)
	if hit > 0.0 and hit < 1.0:
		# Pequenos símbolos de zombaria girando sobre o alvo.
		for i in 3:
			var a := _t * 6.0 + TAU * i / 3.0
			var p := to + Vector2(cos(a) * 9.0, -16.0 + sin(a) * 3.0)
			_px(p, 2.0, Color(color.lightened(0.4), 1.0 - hit))
			_px(p + Vector2(1, -3), 1.0, Color(color.lightened(0.4), 1.0 - hit))


func _draw_cone() -> void:
	var fade := 1.0 - _phase(0.7, 1.0)
	var spread := _phase(0.0, 0.35)
	var palette := [Color8(255, 246, 170), Color8(255, 196, 70), color, color.darkened(0.35)]
	for cell in area:
		var center := cell.get_center()
		var reach := origin.distance_to(center)
		var visible := spread * 110.0 >= reach * 0.9
		if not visible:
			continue
		draw_rect(cell.grow(-2.0), Color(color, 0.16 * fade))
		draw_circle(center + Vector2(0, 4), 11.0, Color(palette[1], 0.14 * fade))
		for i in 12:
			var seed_value := int(center.x * 13.0 + center.y * 7.0) + i
			var rise := fmod(_t * 2.2 + _hash(seed_value), 1.0)
			var p := center + Vector2((_hash(seed_value + 3) - 0.5) * 26.0, 10.0 - rise * 22.0)
			var c: Color = palette[mini(3, int(rise * 4.0))]
			_px(p, 5.0 - rise * 3.5, Color(c, fade * (1.0 - rise * 0.5)))
	# Jato saindo das mãos.
	for i in 10:
		var target_cell: Rect2 = area[i % area.size()] if not area.is_empty() else Rect2(origin, Vector2.ONE)
		var k := fmod(_t * 3.0 + i / 10.0, 1.0) * spread
		_px(origin.lerp(target_cell.get_center(), k), 2.0, Color(palette[i % 3], fade))


func _draw_wave() -> void:
	var progress := _phase(0.0, 0.6)
	var fade := 1.0 - _phase(0.5, 1.0)
	if area.is_empty():
		return
	var bounds := area[0]
	for cell in area:
		bounds = bounds.merge(cell)
	var center := bounds.get_center()
	var size := bounds.size * (0.3 + 0.8 * progress)
	var rect := Rect2(center - size * 0.5, size)
	for inset in [0.0, 3.0, 6.0]:
		var r := rect.grow(-inset * (1.0 - progress))
		draw_rect(r.grow(1.0), Color(OUTLINE, 0.35 * fade), false, 1.0)
		draw_rect(r, Color(color, fade * (1.0 - inset / 9.0)), false, 2.0)
	draw_rect(rect, Color(color, 0.12 * fade))
	# Linhas de pressão saindo do conjurador.
	for i in 8:
		var a := TAU * i / 8.0
		_px(origin + Vector2(cos(a), sin(a)) * (6.0 + 30.0 * progress), 2.0, Color(color.lightened(0.5), fade))


func _draw_heal() -> void:
	var fade := 1.0 - _phase(0.75, 1.0)
	for to in targets:
		draw_circle(to + Vector2(0, -2), 14.0, Color(color, 0.16 * fade))
		draw_rect(Rect2(to + Vector2(-7, -34), Vector2(14, 36)), Color(color, 0.12 * fade))
		_ring(to + Vector2(0, 2), 8.0 + 4.0 * sin(_t * 8.0), color, 0.8 * fade, 2.0)
		for i in 14:
			var k := fmod(_t * 1.4 + _hash(i), 1.0)
			var p := (to + Vector2((_hash(i + 4) - 0.5) * 22.0, 4.0 - k * 34.0)).round()
			var a := fade * (1.0 - k * 0.7)
			if i % 3 == 0:
				# Sinal de "+" com contorno.
				draw_rect(Rect2(p + Vector2(-3, -1), Vector2(7, 3)), Color(OUTLINE, 0.5 * a))
				draw_rect(Rect2(p + Vector2(-1, -3), Vector2(3, 7)), Color(OUTLINE, 0.5 * a))
				draw_rect(Rect2(p + Vector2(-2, 0), Vector2(5, 1)), Color(color, a))
				draw_rect(Rect2(p + Vector2(0, -2), Vector2(1, 5)), Color(color, a))
				_px(p, 1.0, Color(color.lightened(0.7), a))
			else:
				_px(p, 2.0, Color(color.lightened(0.3), a))
	if not targets.is_empty() and origin.distance_to(targets[0]) > 8.0:
		# Fio de luz do conjurador até o alvo.
		var k := _phase(0.0, 0.3)
		for i in 6:
			_px(origin.lerp(targets[0], clampf(k - i * 0.05, 0.0, 1.0)), 2.0 - i * 0.25, Color(color, (1.0 - i / 6.0) * fade))


func _draw_aura() -> void:
	var fade := 1.0 - _phase(0.75, 1.0)
	for to in targets:
		var grow := _phase(0.0, 0.4)
		var center := to + Vector2(0, -10)
		_ring(center, 4.0 + 12.0 * grow, color, fade, 2.0)
		_ring(center, 2.0 + 9.0 * grow, color.lightened(0.5), fade * 0.6, 1.0)
		for i in 6:
			var a := _t * 4.0 + TAU * i / 6.0
			_px(center + Vector2(cos(a) * 14.0, sin(a) * 6.0), 2.0, Color(color.lightened(0.4), fade))


func _draw_mark() -> void:
	var fade := 1.0 - _phase(0.75, 1.0)
	for to in targets:
		var appear := _phase(0.0, 0.35)
		var center := to + Vector2(0, -32)
		var r := 3.0 + 4.0 * appear + sin(_t * 12.0) * 0.8
		# Losango com mira.
		var points := [center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)]
		for i in 4:
			draw_line(points[i].round(), points[(i + 1) % 4].round(), Color(OUTLINE, 0.6 * fade), 3.0)
			draw_line(points[i].round(), points[(i + 1) % 4].round(), Color(color, fade), 1.0)
		_px(center, 2.0, Color(color.lightened(0.6), fade))
		_ring(to + Vector2(0, -12), 4.0 + 14.0 * appear, color, (1.0 - appear) * fade, 1.0)
	if not targets.is_empty():
		var k := _phase(0.0, 0.3)
		for i in 5:
			_px(origin.lerp(targets[0] + Vector2(0, -32), clampf(k - i * 0.05, 0.0, 1.0)), 2.0, Color(color, (1.0 - i / 5.0) * fade))
