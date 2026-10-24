class_name InventoryPanel
extends PanelContainer
## Inventário do grupo (apresentação): itens com ícone e quantidade, equipamento do líder e
## ouro. Os botões enviam comandos ao Inventory, que valida as regras.

signal changed

const ICONS := {
	"item.potion_of_healing": "res://assets/icons/icon_potion.png",
	"item.rations": "res://assets/icons/icon_rations.png",
	"weapon": "res://assets/icons/icon_weapon.png",
	"armor": "res://assets/icons/icon_armor.png",
	"shield": "res://assets/icons/icon_shield.png",
	"coin": "res://assets/icons/icon_coin.png",
}

var _inventory: Inventory
var _character: CharacterData
var _registry: ContentRegistry
var _roller := DiceRoller.new()

var _title: Label
var _gold: Label
var _items: VBoxContainer
var _equipped: VBoxContainer
var _status: Label


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.102, 0.078, 0.137, 0.97)
	style.border_color = Color(0.522, 0.592, 0.722)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	_title = _label("Inventário", 12)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	header.add_child(_icon_rect(ICONS["coin"]))
	_gold = _label("0 PO", 10)
	header.add_child(_gold)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	layout.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	left.add_child(_label("Mochila do grupo", 9, Color(0.522, 0.592, 0.722)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_items = VBoxContainer.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(_label("Equipado", 9, Color(0.522, 0.592, 0.722)))
	_equipped = VBoxContainer.new()
	right.add_child(_equipped)
	_status = _label("", 9, Color(0.878, 0.706, 0.541))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status)


func show_inventory(inventory: Inventory, character: CharacterData, registry: ContentRegistry) -> void:
	_inventory = inventory
	_character = character
	_registry = registry
	_status.text = ""
	_rebuild()


func get_status_text() -> String:
	return _status.text


## Para testes e atalhos: mesmo efeito dos botões.
func use_item(item_id: String) -> Dictionary:
	var result := _inventory.use(_character, item_id, _registry, _roller)
	_status.text = result["error"] if not result["ok"] else "%s recupera %d PV." % [_character.name, result["healed"]]
	_rebuild()
	changed.emit()
	return result


func equip_item(item_id: String) -> Dictionary:
	var result := _inventory.equip(_character, item_id, _registry)
	_status.text = result["error"] if not result["ok"] else "Equipado: %s." % _registry.get_entry("item", item_id)["name"]
	_rebuild()
	changed.emit()
	return result


func unequip(slot: String) -> Dictionary:
	var result := _inventory.unequip(_character, slot)
	_status.text = result["error"] if not result["ok"] else "Guardado na mochila."
	_rebuild()
	changed.emit()
	return result


func _rebuild() -> void:
	if _inventory == null:
		return
	_gold.text = "%d PO" % _inventory.gold
	for child in _items.get_children() + _equipped.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	var sheet := CharacterSheet.build(_character, _registry)
	_title.text = "Inventário · %s · PV %d/%d · CA %d" % [_character.name, _character.current_hp, sheet.max_hp, sheet.armor_class]
	var ids := _inventory.ids(_registry)
	if ids.is_empty():
		_items.add_child(_label("(vazia)", 9))
	for item_id in ids:
		var item := _registry.get_entry("item", item_id)
		var row := _row(item, "%s ×%d" % [item.get("name", item_id), _inventory.count(item_id)])
		match item.get("item_type"):
			"consumable":
				row.add_child(_button("Usar", use_item.bind(item_id)))
			"armor", "shield", "weapon":
				row.add_child(_button("Equipar", equip_item.bind(item_id)))
		_items.add_child(row)
	if not _character.armor_id.is_empty():
		var armor := _registry.get_entry("item", _character.armor_id)
		var row := _row(armor, "%s (armadura)" % armor["name"])
		row.add_child(_button("Remover", unequip.bind("armor")))
		_equipped.add_child(row)
	if not _character.shield_id.is_empty():
		var shield := _registry.get_entry("item", _character.shield_id)
		var row := _row(shield, "%s (escudo)" % shield["name"])
		row.add_child(_button("Remover", unequip.bind("shield")))
		_equipped.add_child(row)
	var seen := {}
	for weapon_id in _character.weapon_ids:
		var weapon := _registry.get_entry("item", weapon_id)
		var label: String = weapon["name"] if not seen.has(weapon_id) else "%s (outra)" % weapon["name"]
		seen[weapon_id] = true
		var row := _row(weapon, "%s (%s)" % [label, weapon["damage"]])
		row.add_child(_button("Remover", unequip.bind("weapon:%s" % weapon_id)))
		_equipped.add_child(row)


func _row(item: Dictionary, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var icon_path: String = ICONS.get(item.get("id"), ICONS.get(item.get("item_type"), ""))
	row.add_child(_icon_rect(icon_path))
	var label := _label(text, 9)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _icon_rect(path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(16, 16)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	if not path.is_empty() and ResourceLoader.exists(path):
		rect.texture = load(path)
	return rect


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 8)
	button.pressed.connect(callback)
	return button


func _label(text: String, size: int, color: Color = Color(0.902, 0.882, 0.827)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
