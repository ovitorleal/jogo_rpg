class_name PartyPanel
extends PanelContainer
## Organização do grupo na estalagem (apresentação): quem está no grupo e quem espera na estalagem,
## com botões para trazer ou deixar companheiros. Quem muda o estado é o ExplorationMap (via roster).

signal join_requested(c: CharacterData)
signal leave_requested(c: CharacterData)

var _column: VBoxContainer
var _status: Label


func _ready() -> void:
	var small := Theme.new()
	small.default_font_size = 9
	theme = small
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.067, 0.086, 0.110, 0.97)
	style.border_color = Color(0.851, 0.659, 0.302)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	add_child(margin)
	var outer := VBoxContainer.new()
	margin.add_child(outer)
	var title := Label.new()
	title.text = "Grupo — %s" % CompanionRoster.INN_NAME
	title.add_theme_font_size_override("font_size", 12)
	outer.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 3)
	scroll.add_child(_column)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	outer.add_child(_status)


func show_party(roster: CompanionRoster, members: Array[CharacterData], registry: ContentRegistry,
		status: String = "") -> void:
	for child in _column.get_children():
		child.queue_free()
	_status.text = status
	_header("No grupo (%d/%d)" % [members.size(), CompanionRoster.MAX_PARTY])
	for i in members.size():
		var c := members[i]
		var button := _row(c, registry, "Deixar na estalagem" if i > 0 else "")
		if button != null:
			button.pressed.connect(func() -> void: leave_requested.emit(c))
	_header("Esperando na estalagem")
	if roster.bench.is_empty():
		_note("Ninguém. Companheiros recrutados com o grupo cheio esperam aqui.")
	for c in roster.bench:
		var button := _row(c, registry, "Trazer para o grupo")
		button.disabled = members.size() >= CompanionRoster.MAX_PARTY
		button.pressed.connect(func() -> void: join_requested.emit(c))
	var missing: Array[String] = []
	for id in registry.ids("companion"):
		if not roster.is_recruited(id):
			missing.append("%s — %s" % [registry.get_entry("companion", id)["name"],
					registry.get_entry("companion", id)["how_to_recruit"]])
	if not missing.is_empty():
		_header("Ainda por conhecer")
		for line in missing:
			_note(line)


## Texto do painel (para testes e acessibilidade).
func get_plain_text() -> String:
	var parts: Array[String] = []
	for row in _column.get_children():
		if row.is_queued_for_deletion():
			continue
		for node in [row] + row.get_children():
			if node is Label:
				parts.append((node as Label).text)
			elif node is Button:
				parts.append("[%s]" % (node as Button).text)
	return "\n".join(parts)


## Botões visíveis, na ordem (para testes).
func buttons() -> Array[Button]:
	var result: Array[Button] = []
	for row in _column.get_children():
		if row.is_queued_for_deletion():
			continue
		for node in row.get_children():
			if node is Button:
				result.append(node)
	return result


func _row(c: CharacterData, registry: ContentRegistry, action_text: String) -> Button:
	var row := HBoxContainer.new()
	_column.add_child(row)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "%s — %s %d · PV %d/%d" % [c.name, registry.get_entry("class", c.class_id).get("name", c.class_id),
			c.level, c.current_hp, CharacterSheet.build(c, registry).max_hp]
	row.add_child(label)
	if action_text.is_empty():
		return null
	var button := Button.new()
	button.text = action_text
	row.add_child(button)
	return button


func _header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.851, 0.659, 0.302))
	_column.add_child(label)


func _note(text: String) -> void:
	var label := Label.new()
	label.text = "  " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.604, 0.659, 0.698))
	_column.add_child(label)
