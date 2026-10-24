class_name ExplorationHud
extends CanvasLayer
## HUD da exploração: aviso de interação, caixa de fala com retrato e ficha. Apenas exibição.

const INTERACT_KEY_HINT := "[E]"

signal dialogue_choice(index: int)

@onready var _prompt_label: Label = %PromptLabel
@onready var _message_panel: PanelContainer = %MessagePanel
@onready var _message_label: Label = %MessageLabel
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _portrait_frame: PanelContainer = %PortraitFrame
@onready var _portrait: TextureRect = %Portrait
@onready var _sheet_panel: CharacterSheetPanel = %SheetPanel
@onready var _sheet_hint: Label = %SheetHint
@onready var _hint_label: Label = %HintLabel
@onready var _choices: VBoxContainer = %Choices

var inventory_panel: InventoryPanel
var journal_panel: JournalPanel

const DEFAULT_HINT := "[E] Continuar"


func _ready() -> void:
	inventory_panel = _overlay(InventoryPanel.new(), "InventoryPanel")
	journal_panel = _overlay(JournalPanel.new(), "JournalPanel")
	hide_prompt()
	hide_message()
	hide_sheet()


func _overlay(panel: PanelContainer, panel_name: String) -> Variant:
	panel.name = panel_name
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_top = 18
	panel.offset_right = -40
	panel.offset_bottom = -22
	panel.visible = false
	add_child(panel)
	move_child(panel, _sheet_hint.get_index())
	return panel


func show_prompt(text: String) -> void:
	_prompt_label.text = "%s %s" % [INTERACT_KEY_HINT, text]
	_prompt_label.visible = true


func hide_prompt() -> void:
	_prompt_label.visible = false


func is_prompt_visible() -> bool:
	return _prompt_label.visible


## Mostra uma fala. Com retrato, ele aparece em destaque à esquerda; sem nome nem retrato,
## a caixa vira uma mensagem simples do sistema.
func show_message(text: String, speaker_name: String = "", portrait: Texture2D = null,
		hint: String = DEFAULT_HINT) -> void:
	_message_label.text = text
	_hint_label.text = hint
	_speaker_label.text = speaker_name
	_speaker_label.visible = not speaker_name.is_empty()
	_portrait.texture = portrait
	_portrait_frame.visible = portrait != null
	_message_panel.visible = true


func hide_message() -> void:
	_message_panel.visible = false
	_clear_choices()


## Fala de diálogo com escolhas (botões navegáveis por teclado e mouse).
func show_dialogue(speaker_name: String, portrait: Texture2D, text: String, options: Array[String]) -> void:
	show_message(text, speaker_name, portrait, "Escolha uma resposta" if not options.is_empty() else DEFAULT_HINT)
	_clear_choices()
	for i in options.size():
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, options[i]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(func() -> void: dialogue_choice.emit(i))
		_choices.add_child(button)
	if _choices.get_child_count() > 0:
		var first := _choices.get_child(0) as Button
		# Adiado e protegido: a escolha pode ser feita (e o botão removido) antes do próximo quadro.
		(func() -> void:
			if is_instance_valid(first) and first.is_inside_tree():
				first.grab_focus()).call_deferred()


func dialogue_options() -> Array[String]:
	var result: Array[String] = []
	for child in _choices.get_children():
		result.append((child as Button).text)
	return result


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func is_message_open() -> bool:
	return _message_panel.visible


func get_message_text() -> String:
	return _message_label.text


func get_speaker_name() -> String:
	return _speaker_label.text if _speaker_label.visible else ""


func get_portrait() -> Texture2D:
	return _portrait.texture if _portrait_frame.visible else null


func show_sheet(sheet: CharacterSheet) -> void:
	hide_overlays()
	_sheet_panel.show_sheet(sheet)
	_sheet_panel.visible = true
	_show_overlay_hint("[C] ou [Esc] fechar ficha")


func show_inventory(inventory: Inventory, character: CharacterData, registry: ContentRegistry) -> void:
	hide_overlays()
	inventory_panel.show_inventory(inventory, character, registry)
	inventory_panel.visible = true
	_show_overlay_hint("[I] ou [Esc] fechar inventário")


func show_journal(quests: QuestLog, registry: ContentRegistry) -> void:
	hide_overlays()
	journal_panel.show_journal(quests, registry)
	journal_panel.visible = true
	_show_overlay_hint("[J] ou [Esc] fechar diário")


func _show_overlay_hint(text: String) -> void:
	_sheet_hint.text = text
	_sheet_hint.visible = true


func hide_sheet() -> void:
	_sheet_panel.visible = false
	_sheet_hint.visible = false


func is_sheet_open() -> bool:
	return _sheet_panel.visible


func is_overlay_open() -> bool:
	return _sheet_panel.visible or inventory_panel.visible or journal_panel.visible


func hide_overlays() -> void:
	hide_sheet()
	inventory_panel.visible = false
	journal_panel.visible = false


func get_sheet_text() -> String:
	return _sheet_panel.get_plain_text()
