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
var pause_menu: PauseMenu
var choices_overlay: PanelContainer
var choices_panel: ChoicesPanel
var party_panel: PartyPanel
var _objective_label: Label

const DEFAULT_HINT := "[E] Continuar"


func _ready() -> void:
	inventory_panel = _overlay(InventoryPanel.new(), "InventoryPanel")
	journal_panel = _overlay(JournalPanel.new(), "JournalPanel")
	choices_overlay = _overlay(_build_choices_overlay(), "ChoicesOverlay")
	party_panel = _overlay(PartyPanel.new(), "PartyPanel")
	pause_menu = _overlay(PauseMenu.new(), "PauseMenu")
	pause_menu.set_anchors_preset(Control.PRESET_CENTER)
	pause_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_menu.offset_left = 0
	pause_menu.offset_top = 0
	pause_menu.offset_right = 0
	pause_menu.offset_bottom = 0
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.position = Vector2(6, 16)
	_objective_label.size = Vector2(420, 12)
	_objective_label.add_theme_font_size_override("font_size", 8)
	_objective_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	_objective_label.add_theme_color_override("font_outline_color", Color(0.102, 0.078, 0.137))
	_objective_label.add_theme_constant_override("outline_size", 3)
	add_child(_objective_label)
	move_child(_objective_label, 1)
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


## Objetivo atual no canto superior esquerdo ("" esconde).
func set_objective(text: String) -> void:
	_objective_label.text = "Objetivo: %s" % text if not text.is_empty() else ""
	_objective_label.visible = not text.is_empty()


func objective_text() -> String:
	return _objective_label.text


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


func show_journal(quests: QuestLog, registry: ContentRegistry, lore: Array[Dictionary] = []) -> void:
	hide_overlays()
	journal_panel.show_journal(quests, registry, lore)
	journal_panel.visible = true
	_show_overlay_hint("[J] ou [Esc] fechar diário")


func _build_choices_overlay() -> PanelContainer:
	var panel := PanelContainer.new()
	var small := Theme.new()
	small.default_font_size = 9
	panel.theme = small
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.102, 0.078, 0.137, 0.97)
	style.border_color = Color(0.878, 0.706, 0.541)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var title := Label.new()
	title.text = "Escolhas de nível e talentos"
	title.add_theme_font_size_override("font_size", 12)
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	choices_panel = ChoicesPanel.new()
	choices_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(choices_panel)
	return panel


func show_choices(character: CharacterData, registry: ContentRegistry) -> void:
	hide_overlays()
	choices_panel.show_choices(character, registry)
	choices_overlay.visible = true
	_show_overlay_hint("[L] ou [Esc] fechar · as escolhas valem na hora")


func show_party(roster: CompanionRoster, members: Array[CharacterData], registry: ContentRegistry,
		status: String = "") -> void:
	hide_overlays()
	party_panel.show_party(roster, members, registry, status)
	party_panel.visible = true
	_show_overlay_hint("[Esc] fechar")


## Acrescenta uma dica à linha de teclas do painel aberto (ex.: "[Tab] próximo membro").
func extend_overlay_hint(extra: String) -> void:
	if _sheet_hint.visible and not extra in _sheet_hint.text:
		_sheet_hint.text = "%s · %s" % [_sheet_hint.text, extra]


func show_pause_menu(status: String) -> void:
	hide_overlays()
	pause_menu.open(status)
	_show_overlay_hint("[Esc] voltar ao jogo")


func _show_overlay_hint(text: String) -> void:
	_sheet_hint.text = text
	_sheet_hint.visible = true


func hide_sheet() -> void:
	_sheet_panel.visible = false
	_sheet_hint.visible = false


func is_sheet_open() -> bool:
	return _sheet_panel.visible


func is_overlay_open() -> bool:
	return _sheet_panel.visible or inventory_panel.visible or journal_panel.visible or pause_menu.visible 			or choices_overlay.visible or party_panel.visible


func hide_overlays() -> void:
	hide_sheet()
	inventory_panel.visible = false
	journal_panel.visible = false
	pause_menu.visible = false
	choices_overlay.visible = false
	party_panel.visible = false


func get_sheet_text() -> String:
	return _sheet_panel.get_plain_text()
