class_name ExplorationHud
extends CanvasLayer
## HUD da exploração: aviso de interação, caixa de fala com retrato e ficha. Apenas exibição.

const INTERACT_KEY_HINT := "[E]"

@onready var _prompt_label: Label = %PromptLabel
@onready var _message_panel: PanelContainer = %MessagePanel
@onready var _message_label: Label = %MessageLabel
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _portrait_frame: PanelContainer = %PortraitFrame
@onready var _portrait: TextureRect = %Portrait
@onready var _sheet_panel: CharacterSheetPanel = %SheetPanel
@onready var _sheet_hint: Label = %SheetHint


func _ready() -> void:
	hide_prompt()
	hide_message()
	hide_sheet()


func show_prompt(text: String) -> void:
	_prompt_label.text = "%s %s" % [INTERACT_KEY_HINT, text]
	_prompt_label.visible = true


func hide_prompt() -> void:
	_prompt_label.visible = false


func is_prompt_visible() -> bool:
	return _prompt_label.visible


## Mostra uma fala. Com retrato, ele aparece em destaque à esquerda; sem nome nem retrato,
## a caixa vira uma mensagem simples do sistema.
func show_message(text: String, speaker_name: String = "", portrait: Texture2D = null) -> void:
	_message_label.text = text
	_speaker_label.text = speaker_name
	_speaker_label.visible = not speaker_name.is_empty()
	_portrait.texture = portrait
	_portrait_frame.visible = portrait != null
	_message_panel.visible = true


func hide_message() -> void:
	_message_panel.visible = false


func is_message_open() -> bool:
	return _message_panel.visible


func get_message_text() -> String:
	return _message_label.text


func get_speaker_name() -> String:
	return _speaker_label.text if _speaker_label.visible else ""


func get_portrait() -> Texture2D:
	return _portrait.texture if _portrait_frame.visible else null


func show_sheet(sheet: CharacterSheet) -> void:
	_sheet_panel.show_sheet(sheet)
	_sheet_panel.visible = true
	_sheet_hint.visible = true


func hide_sheet() -> void:
	_sheet_panel.visible = false
	_sheet_hint.visible = false


func is_sheet_open() -> bool:
	return _sheet_panel.visible


func get_sheet_text() -> String:
	return _sheet_panel.get_plain_text()
