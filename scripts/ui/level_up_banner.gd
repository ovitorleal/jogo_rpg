class_name LevelUpBanner
extends Control
## Aviso de subida de nível (apresentação): faixa dourada no alto da tela com "VOCÊ SUBIU DE NÍVEL!" (ou o
## nome do companheiro), o novo nível e o que mudou. Vários avisos entram numa fila e aparecem um de cada vez.

const SHOW_TIME := 2.6
const GOLD := Color(1.0, 0.84, 0.42)

var _queue: Array[Dictionary] = []
var _showing := false
var _title: Label
var _subtitle: Label
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = 40
	offset_bottom = 96
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.02, 0.88)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(3)
	style.shadow_color = Color(1.0, 0.75, 0.3, 0.45)
	style.shadow_size = 8
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 4
	style.content_margin_bottom = 5
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_panel.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", GOLD)
	_title.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.0))
	_title.add_theme_constant_override("outline_size", 4)
	column.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 8)
	_subtitle.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	column.add_child(_subtitle)
	visible = false


## Põe um aviso na fila. leader = o personagem do jogador ("VOCÊ"); senão usa o nome.
func announce(character_name: String, level: int, details: String, leader: bool) -> void:
	_queue.append({"name": character_name, "level": level, "details": details, "leader": leader})
	if not _showing:
		_next()


func is_showing() -> bool:
	return _showing


func title_text() -> String:
	return _title.text


func subtitle_text() -> String:
	return _subtitle.text


func _next() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	_showing = true
	var item: Dictionary = _queue.pop_front()
	_title.text = "VOCÊ SUBIU DE NÍVEL!" if item["leader"] else "%s SUBIU DE NÍVEL!" % str(item["name"]).get_slice(" ", 0).to_upper()
	_subtitle.text = "Nível %d · %s" % [item["level"], item["details"]]
	visible = true
	_panel.reset_size()
	_panel.pivot_offset = _panel.size / 2.0
	_panel.position = Vector2((get_viewport_rect().size.x - _panel.size.x) / 2.0, 0.0)
	_panel.scale = Vector2(0.6, 0.6)
	_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(_panel, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.12)
	tween.tween_interval(SHOW_TIME)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(_next)
