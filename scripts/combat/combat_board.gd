class_name CombatBoard
extends Control
## Desenha a arena em grade (com os mesmos tiles de grama da exploração), destaques de
## movimento e de alvos, e mantém uma CombatToken animada por combatente. Converte cliques
## em casas. Só apresentação. Estados importantes não dependem só de cor: alvos têm moldura
## tracejada, o participante do turno tem moldura dupla e quem caiu fica tombado.

signal cell_clicked(cell: Vector2i)

const CELL := 32
const TILES := "res://assets/tilesets/overworld_tiles.png"
const GRID_LINE := Color(0.05, 0.1, 0.05, 0.16)
const MOVE_FILL := Color(0.55, 0.75, 1.0, 0.30)
const MOVE_LINE := Color(0.75, 0.88, 1.0, 0.55)
const TARGET_LINE := Color8(255, 90, 70)
const CURRENT_LINE := Color8(255, 226, 110)
const AIM_FILL := Color(1.0, 0.55, 0.2, 0.28)
const AIM_LINE := Color8(255, 150, 70)

var manager: CombatManager
var reachable: Dictionary = {}
var targets: Array[Combatant] = []
## Casas para escolher a direção de uma magia de área (cone/cubo).
var aim_cells: Array[Vector2i] = []

var _tokens := {}
var _tiles: Texture2D


func _ready() -> void:
	_tiles = load(TILES) if ResourceLoader.exists(TILES) else null
	clip_contents = false


func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL)


## Ponto dos pés de quem está na casa.
func cell_feet(cell: Vector2i) -> Vector2:
	return cell_to_local(cell) + Vector2(CELL / 2.0, CELL - 4.0)


func local_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))


func board_size() -> Vector2:
	return Vector2(manager.arena_size * CELL) if manager != null else Vector2.ZERO


func token_for(unit: Combatant) -> CombatToken:
	return _tokens.get(unit.id)


## Cria fichas que faltam e, com snap = true, coloca todas na casa atual do combatente.
func sync_tokens(snap: bool = true) -> void:
	if manager == null:
		return
	for unit in manager.combatants:
		var token: CombatToken = _tokens.get(unit.id)
		if token == null:
			token = CombatToken.new()
			token.name = "Token_%s" % unit.id.replace("#", "_").replace(".", "_")
			add_child(token)
			token.setup(unit)
			token.position = cell_feet(unit.position)
			_tokens[unit.id] = token
		if snap:
			token.position = cell_feet(unit.position)
		token.z_index = unit.position.y
		if not unit.is_up() and not token.downed:
			token.downed = true
			token.visible = unit.team == Combatant.Team.PARTY
		token.refresh(snap)


func refresh() -> void:
	custom_minimum_size = board_size()
	queue_redraw()


## Texto que sobe e some (dano, erro, crítico).
func float_text(text: String, at: Vector2, color: Color, big: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12 if big else 10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color8(26, 16, 32))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(80, 16)
	label.position = at - Vector2(40, 34)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 14.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.35)
	tween.tween_callback(label.queue_free)


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
			_draw_ground(Vector2i(x, y))
	for y in manager.arena_size.y + 1:
		draw_line(Vector2(0, y * CELL), Vector2(manager.arena_size.x * CELL, y * CELL), GRID_LINE)
	for x in manager.arena_size.x + 1:
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, manager.arena_size.y * CELL), GRID_LINE)
	for cell: Vector2i in reachable:
		var rect := Rect2(cell_to_local(cell) + Vector2(2, 2), Vector2(CELL - 4, CELL - 4))
		draw_rect(rect, MOVE_FILL)
		draw_rect(rect, MOVE_LINE, false, 1.0)
	for cell in aim_cells:
		var aim_rect := Rect2(cell_to_local(cell) + Vector2(3, 3), Vector2(CELL - 6, CELL - 6))
		draw_rect(aim_rect, AIM_FILL)
		_draw_dashed_rect(aim_rect, AIM_LINE)
	var current := manager.current()
	if current != null:
		var origin := cell_to_local(current.position)
		draw_rect(Rect2(origin + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), CURRENT_LINE, false, 1.0)
		draw_rect(Rect2(origin + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), CURRENT_LINE, false, 1.0)
	for unit in targets:
		_draw_dashed_rect(Rect2(cell_to_local(unit.position) + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), TARGET_LINE)


## Cada casa = 2x2 tiles de grama do atlas da exploração, variando por posição.
func _draw_ground(cell: Vector2i) -> void:
	var origin := cell_to_local(cell)
	if _tiles == null:
		draw_rect(Rect2(origin, Vector2(CELL, CELL)), Color8(79, 154, 62))
		return
	for sy in 2:
		for sx in 2:
			var h := absi((cell.x * 7 + sx) * 92821 ^ (cell.y * 5 + sy) * 68917) % 100
			var variant := 0 if h < 62 else (1 if h < 86 else (2 if h < 93 else 3))
			draw_texture_rect_region(_tiles, Rect2(origin + Vector2(sx * 16, sy * 16), Vector2(16, 16)),
					Rect2(variant * 16, 0, 16, 16))


func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 3.0)
