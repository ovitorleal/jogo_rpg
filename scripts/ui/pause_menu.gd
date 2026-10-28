class_name PauseMenu
extends PanelContainer
## Menu do mapa (Esc): continuar, salvar agora e voltar ao título. Só apresentação; quem salva
## é o SaveManager, chamado pelo ExplorationMap.

signal resume_requested
signal save_requested
signal title_requested

var resume_button: Button
var save_button: Button
var title_button: Button
var _status: Label


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.102, 0.078, 0.137, 0.97)
	style.border_color = Color(0.878, 0.706, 0.541)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	column.add_child(title)
	resume_button = _button(column, "Continuar jogo", resume_requested)
	save_button = _button(column, "Salvar agora", save_requested)
	title_button = _button(column, "Voltar ao título", title_requested)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 200
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 8)
	_status.add_theme_color_override("font_color", Color(0.522, 0.592, 0.722))
	column.add_child(_status)


func open(status: String) -> void:
	set_status(status)
	visible = true
	resume_button.grab_focus.call_deferred()


func set_status(text: String) -> void:
	_status.text = text


func get_status() -> String:
	return _status.text


func _button(parent: Control, text: String, emitted: Signal) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.x = 160
	button.pressed.connect(func() -> void: emitted.emit())
	parent.add_child(button)
	return button
