class_name ChoicesPanel
extends VBoxContainer
## Mostra e edita as escolhas de um personagem (CharacterChoices): talentos, atributos, estilo de
## luta, maestria, perícias, subclasse... Só apresentação: cada mudança grava em CharacterData,
## completa as escolhas dependentes com CharacterChoices.fill_defaults e emite "changed".

signal changed

var _character: CharacterData = null
var _registry: ContentRegistry = null


func show_choices(c: CharacterData, registry: ContentRegistry) -> void:
	_character = c
	_registry = registry
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if _character == null:
		return
	var specs := CharacterChoices.specs(_character, _registry)
	if specs.is_empty():
		var none := Label.new()
		none.text = "Nenhuma escolha disponível."
		add_child(none)
		return
	for spec in specs:
		var label := Label.new()
		label.text = "%s%s" % [spec["label"], " (escolha %d)" % spec["count"] if int(spec["count"]) > 1 else ""]
		label.add_theme_color_override("font_color", Color(0.878, 0.706, 0.541))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(label)
		if spec["options"].is_empty():
			var empty := Label.new()
			empty.text = "(nenhuma opção disponível ainda)"
			add_child(empty)
		elif spec["key"] == "subclass":
			add_child(_option_button(spec, [_character.subclass_id], 0))
		elif spec["allow_duplicates"] or int(spec["count"]) == 1:
			var chosen := _character.choice(spec["key"])
			for i in int(spec["count"]):
				add_child(_option_button(spec, chosen, i))
		else:
			add_child(_checkboxes(spec))


func _option_button(spec: Dictionary, chosen: Array, slot: int) -> OptionButton:
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	for entry: Dictionary in spec["options"]:
		option.add_item(str(entry["name"]))
		option.set_item_metadata(option.item_count - 1, str(entry["id"]))
		option.set_item_tooltip(option.item_count - 1, str(entry.get("description", "")))
		if slot < chosen.size() and str(entry["id"]) == str(chosen[slot]):
			option.select(option.item_count - 1)
	option.item_selected.connect(_on_option_selected.bind(option, spec, slot))
	return option


func _checkboxes(spec: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	var chosen := _character.choice(spec["key"])
	for entry: Dictionary in spec["options"]:
		var check := CheckBox.new()
		check.text = str(entry["name"])
		check.tooltip_text = str(entry.get("description", ""))
		var id := str(entry["id"])
		check.button_pressed = id in chosen
		check.toggled.connect(_on_toggled.bind(spec, id))
		grid.add_child(check)
	return grid


func _on_option_selected(index: int, option: OptionButton, spec: Dictionary, slot: int) -> void:
	var value := str(option.get_item_metadata(index))
	if spec["key"] == "subclass":
		_character.subclass_id = value
	else:
		var chosen := _character.choice(spec["key"])
		while chosen.size() <= slot:
			chosen.append(value)
		chosen[slot] = value
		_character.choices[spec["key"]] = chosen
	_commit()


func _on_toggled(pressed: bool, spec: Dictionary, id: String) -> void:
	var chosen := _character.choice(spec["key"])
	if pressed and not id in chosen:
		# Grupo cheio: a escolha mais antiga dá lugar à nova.
		if chosen.size() >= int(spec["count"]):
			chosen.pop_front()
		chosen.append(id)
	elif not pressed:
		chosen.erase(id)
	_character.choices[spec["key"]] = chosen
	_commit()


func _commit() -> void:
	CharacterChoices.fill_defaults(_character, _registry)
	changed.emit()
	_rebuild.call_deferred()


func get_plain_text() -> String:
	var parts := PackedStringArray()
	for child in get_children():
		if child is Label:
			parts.append((child as Label).text)
	return "\n".join(parts)
