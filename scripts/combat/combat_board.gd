class_name CombatBoard
extends Control
## Desenha a arena em grade e os combatentes; converte cliques em casas. Só apresentação.
## Estados importantes não dependem só de cor: alvos têm moldura tracejada, o participante
## do turno tem moldura dupla e quem caiu fica acinzentado e deitado.

signal cell_clicked(cell: Vector2i)

const CELL := 28
const GRASS_A := Color8(74, 122, 58)
const GRASS_B := Color8(68, 114, 53)
const GRID_LINE := Color(0, 0, 0, 0.18)
const MOVE_FILL := Color(0.52, 0.59, 0.72, 0.45)
const TARGET_LINE := Color8(214, 70, 60)
const CURRENT_LINE := Color8(230, 214, 90)
const HP_BACK := Color8(26, 20, 35)
const HP_PARTY := Color8(111, 190, 90)
const HP_ENEMY := Color8(214, 70, 60)

var manager: CombatManager
var reachable: Dictionary = {}
var targets: Array[Combatant] = []

var _textures := {}


func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL)


func local_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))


func board_size() -> Vector2:
	return Vector2(manager.arena_size * CELL) if manager != null else Vector2.ZERO


func refresh() -> void:
	custom_minimum_size = board_size()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and manager != null:
		var cell := local_to_cell(click.position)
		if cell.x >= 0 and cell.y >= 0 and cell.x < manager.arena_size.x and cell.y < manager.arena_size.y:
			accept_event()
			cell_clicked.emit(cell)


func _draw() -> void:
	if manager == null:
		return
	for y in manager.arena_size.y:
		for x in manager.arena_size.x:
			var rect := Rect2(cell_to_local(Vector2i(x, y)), Vector2(CELL, CELL))
			draw_rect(rect, GRASS_A if (x + y) % 2 == 0 else GRASS_B)
			draw_rect(rect, GRID_LINE, false, 1.0)
	for cell: Vector2i in reachable:
		draw_rect(Rect2(cell_to_local(cell) + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), MOVE_FILL)

	var current := manager.current()
	for unit in manager.combatants:
		if unit.team == Combatant.Team.ENEMY and not unit.is_up():
			continue
		_draw_unit(unit, unit == current)
	for unit in targets:
		_draw_dashed_rect(Rect2(cell_to_local(unit.position) + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), TARGET_LINE)


func _draw_unit(unit: Combatant, is_current: bool) -> void:
	var origin := cell_to_local(unit.position)
	var texture := _texture(unit.sprite_path)
	var sprite_rect := Rect2(origin + Vector2((CELL - 32) / 2.0, CELL - 32 - 1), Vector2(32, 32))
	if texture != null:
		if unit.is_up():
			draw_texture_rect(texture, sprite_rect, false)
		else:
			# Caído: deitado de lado e acinzentado.
			draw_set_transform(origin + Vector2(CELL / 2.0, CELL / 2.0), PI / 2.0)
			draw_texture_rect(texture, Rect2(Vector2(-16, -16), Vector2(32, 32)), false, Color(0.5, 0.5, 0.5, 0.8))
			draw_set_transform(Vector2.ZERO)
	if is_current:
		draw_rect(Rect2(origin + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), CURRENT_LINE, false, 1.0)
		draw_rect(Rect2(origin + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), CURRENT_LINE, false, 1.0)
	var bar := Rect2(origin + Vector2(3, CELL - 4), Vector2(CELL - 6, 3))
	draw_rect(bar, HP_BACK)
	var ratio := float(unit.hp) / float(maxi(1, unit.max_hp))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)),
			HP_PARTY if unit.team == Combatant.Team.PARTY else HP_ENEMY)


func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 3.0)


func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]
