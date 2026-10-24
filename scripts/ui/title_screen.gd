extends Control
## Tela de título provisória.
## Apenas apresentação: não contém regras nem estado de jogo.

const NEW_GAME_SCENE := "res://scenes/menus/character_creation.tscn"
const CONTINUE_PENDING_TOOLTIP := "Nenhum salvamento disponível (sistema de salvamento previsto para a Fase 6)."

## Atribuição exigida pela licença CC BY 4.0 do SRD 5.2 (texto oficial, não traduzir).
const SRD_ATTRIBUTION := "This work includes material from the System Reference Document 5.2 (\"SRD 5.2\") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode."
const NOT_OFFICIAL_NOTICE := "Este jogo não é um produto oficial de Dungeons & Dragons e não é afiliado à Wizards of the Coast."
const GODOT_NOTICE := "Feito com Godot Engine (licença MIT). Copyright (c) 2014-present Godot Engine contributors. Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur. Componentes de terceiros do motor: ver COPYRIGHT.txt do Godot."

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel
@onready var _version_label: Label = %VersionLabel
@onready var _credits_panel: PanelContainer = %CreditsPanel
@onready var _credits_text: RichTextLabel = %CreditsText
@onready var _close_credits_button: Button = %CloseCreditsButton


func _ready() -> void:
	var game_version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	_version_label.text = "v%s · Godot %s" % [game_version, Engine.get_version_info().string]

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.disabled = true
	_continue_button.tooltip_text = CONTINUE_PENDING_TOOLTIP
	_credits_button.pressed.connect(_on_credits_pressed)
	_close_credits_button.pressed.connect(_on_close_credits_pressed)
	# Fechar a aba é responsabilidade do navegador; "Sair" só faz sentido no desktop.
	_quit_button.visible = not OS.has_feature("web")
	_quit_button.pressed.connect(_on_quit_pressed)

	_credits_text.text = credits_text()
	_status_label.text = ""
	_new_game_button.grab_focus()


static func credits_text() -> String:
	return "\n\n".join(PackedStringArray([
		"[b]Créditos e licenças[/b]",
		"[b]Regras[/b]\n%s" % SRD_ATTRIBUTION,
		NOT_OFFICIAL_NOTICE,
		"[b]Motor[/b]\n%s" % GODOT_NOTICE,
		"[b]Arte[/b]\nArte provisória original do projeto.",
	]))


func _unhandled_input(event: InputEvent) -> void:
	if _credits_panel.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_credits_pressed()


func _on_new_game_pressed() -> void:
	var err := get_tree().change_scene_to_file(NEW_GAME_SCENE)
	if err != OK:
		_status_label.text = "Não foi possível iniciar o jogo (%s)." % error_string(err)
		push_error("Falha ao carregar %s: %s" % [NEW_GAME_SCENE, error_string(err)])


func _on_credits_pressed() -> void:
	_credits_panel.visible = true
	_close_credits_button.grab_focus()


func _on_close_credits_pressed() -> void:
	_credits_panel.visible = false
	_credits_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()
