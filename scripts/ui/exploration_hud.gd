class_name ExplorationHud
extends CanvasLayer
## HUD da exploração: aviso de interação e caixa de mensagem. Apenas exibição.

const INTERACT_KEY_HINT := "[E]"

@onready var _prompt_label: Label = %PromptLabel
@onready var _message_panel: PanelContainer = %MessagePanel
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	hide_prompt()
	hide_message()


func show_prompt(text: String) -> void:
	_prompt_label.text = "%s %s" % [INTERACT_KEY_HINT, text]
	_prompt_label.visible = true


func hide_prompt() -> void:
	_prompt_label.visible = false


func is_prompt_visible() -> bool:
	return _prompt_label.visible


func show_message(text: String) -> void:
	_message_label.text = text
	_message_panel.visible = true


func hide_message() -> void:
	_message_panel.visible = false


func is_message_open() -> bool:
	return _message_panel.visible


func get_message_text() -> String:
	return _message_label.text
