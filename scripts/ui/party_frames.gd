class_name PartyFrames
extends VBoxContainer
## Retratos do grupo na lateral (apresentação): retrato, nome, nível e barra de PV de cada membro, com o líder
## destacado. Clicar num retrato pede a ficha daquele membro (quem abre é o ExplorationMap).

signal member_pressed(index: int)

const FRAME_SIZE := Vector2(40, 40)
const GOLD := Color(0.878, 0.706, 0.541)
const DARK := Color(0.102, 0.078, 0.137, 0.92)
const HP_GOOD := Color(0.36, 0.72, 0.38)
const HP_LOW := Color(0.86, 0.32, 0.27)

var _frames: Array[Control] = []


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Monta um quadro por membro do grupo (o primeiro é o líder).
func show_party(members: Array[CharacterData], registry: ContentRegistry) -> void:
	for frame in _frames:
		frame.queue_free()
	_frames.clear()
	for i in members.size():
		var frame := _build_frame(members[i], registry, i)
		add_child(frame)
		_frames.append(frame)


func frame_count() -> int:
	return _frames.size()


## Texto do quadro (para testes): "Nome · Nv N · PV a/b".
func frame_text(index: int) -> String:
	return str(_frames[index].get_meta("summary", "")) if index < _frames.size() else ""


func _build_frame(c: CharacterData, registry: ContentRegistry, index: int) -> Control:
	var max_hp := CharacterSheet.build(c, registry).max_hp
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.set_meta("summary", "%s · Nv %d · PV %d/%d" % [c.name, c.level, c.current_hp, max_hp])
	var button := Button.new()
	button.custom_minimum_size = FRAME_SIZE
	button.tooltip_text = "%s — nível %d\nClique para ver a ficha" % [c.name, c.level]
	button.focus_mode = Control.FOCUS_NONE
	var border := StyleBoxFlat.new()
	border.bg_color = DARK
	border.border_color = GOLD if index == 0 else GOLD.darkened(0.45)
	border.set_border_width_all(2 if index == 0 else 1)
	border.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", border)
	var hover := border.duplicate() as StyleBoxFlat
	hover.border_color = Color(1.0, 0.86, 0.52)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void: member_pressed.emit(index))
	var portrait := TextureRect.new()
	portrait.texture = Appearance.portrait_texture(c, registry) if registry.has("appearance",
			c.species_id.replace("species.", "appearance.")) else null
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 2
	portrait.offset_top = 2
	portrait.offset_right = -2
	portrait.offset_bottom = -2
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if c.current_hp <= 0:
		portrait.modulate = Color(0.45, 0.45, 0.45)
	button.add_child(portrait)
	var level := Label.new()
	level.text = str(c.level)
	level.add_theme_font_size_override("font_size", 7)
	level.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	level.add_theme_color_override("font_outline_color", Color.BLACK)
	level.add_theme_constant_override("outline_size", 3)
	level.position = Vector2(3, 27)
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(level)
	box.add_child(button)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(FRAME_SIZE.x, 4)
	bar.show_percentage = false
	bar.max_value = maxi(1, max_hp)
	bar.value = clampi(c.current_hp, 0, max_hp)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.04, 0.07, 0.9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = HP_LOW if c.current_hp * 3 <= max_hp else HP_GOOD
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var name_label := Label.new()
	name_label.text = c.name.get_slice(" ", 0)
	name_label.custom_minimum_size.x = FRAME_SIZE.x
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 6)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	return box
