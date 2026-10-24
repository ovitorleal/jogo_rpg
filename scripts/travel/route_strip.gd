class_name RouteStrip
extends Control
## Faixa ilustrada da rota: trilha com um marco por trecho, árvores ao redor e o herói animado
## andando de marco em marco. Só apresentação.

const SHEET := "res://assets/characters/hero_sheet.png"
const TREE := "res://assets/environments/tree.png"
const PINE := "res://assets/environments/pine.png"
const GRASS := Color8(79, 154, 62)
const GRASS_DARK := Color8(63, 122, 52)
const PATH := Color8(156, 108, 64)
const PATH_EDGE := Color8(122, 82, 50)
const NODE := Color8(255, 226, 110)
const NODE_DONE := Color8(230, 225, 211)
const NODE_LINE := Color8(26, 16, 32)

var segments: int = 4
var done: int = 0
var start_name: String = ""
var end_name: String = ""

var _hero: AnimatedSprite2D
var _tree: Texture2D
var _pine: Texture2D


func _ready() -> void:
	clip_contents = true
	_tree = load(TREE)
	_pine = load(PINE)
	_hero = AnimatedSprite2D.new()
	_hero.sprite_frames = SpriteLibrary.frames_for(SHEET)
	_hero.offset = SpriteLibrary.FEET_OFFSET
	add_child(_hero)
	_hero.play(&"idle_right")
	resized.connect(_place_hero)


func configure(total: int, completed: int, from_name: String, to_name: String) -> void:
	segments = maxi(1, total)
	done = completed
	start_name = from_name
	end_name = to_name
	_place_hero()
	queue_redraw()


func node_position(index: int) -> Vector2:
	var margin := 48.0
	var t := float(index) / float(segments)
	var x := lerpf(margin, size.x - margin, t)
	return Vector2(x, size.y * 0.62 + sin(t * PI * 2.0) * 6.0)


## Anda até o marco "completed"; retorna quando chega.
func walk_to(completed: int, animate: bool) -> void:
	done = completed
	queue_redraw()
	if not animate or not is_inside_tree():
		_place_hero()
		return
	_hero.play(&"walk_right")
	var tween := create_tween()
	tween.tween_property(_hero, "position", node_position(done), 0.9)
	await tween.finished
	_hero.play(&"idle_right")


func _place_hero() -> void:
	if _hero != null:
		_hero.position = node_position(done)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GRASS)
	for i in 40:
		var h := absi(i * 92821 ^ 68917) % 1000
		draw_rect(Rect2(Vector2(h * size.x / 1000.0, (h * 7 % 100) * size.y / 100.0), Vector2(2, 1)), GRASS_DARK)
	# Floresta no alto e embaixo.
	var x := -8.0
	var i := 0
	while x < size.x + 16.0:
		var tex := _pine if i % 3 == 0 else _tree
		if tex != null:
			draw_texture(tex, Vector2(x, -18.0 + (i % 2) * 4.0))
			if i % 2 == 0:
				draw_texture(tex, Vector2(x + 10.0, size.y - 34.0))
		x += 26.0
		i += 1
	# Trilha e marcos.
	var points := PackedVector2Array()
	for s in segments * 8 + 1:
		var t := float(s) / float(segments * 8)
		points.append(node_position(0).lerp(node_position(segments), t) * Vector2(1, 0)
				+ Vector2(0, size.y * 0.62 + sin(t * PI * 2.0) * 6.0))
	draw_polyline(points, PATH_EDGE, 12.0)
	draw_polyline(points, PATH, 9.0)
	for n in segments + 1:
		var p := node_position(n)
		draw_circle(p, 5.0, NODE_LINE)
		draw_circle(p, 4.0, NODE_DONE if n <= done else NODE)
	var font := get_theme_default_font()
	if font != null:
		draw_string_outline(font, node_position(0) + Vector2(-30, 20), start_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, NODE_LINE)
		draw_string(font, node_position(0) + Vector2(-30, 20), start_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		var end := node_position(segments) + Vector2(-60, 20)
		draw_string_outline(font, end, end_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, NODE_LINE)
		draw_string(font, end, end_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
