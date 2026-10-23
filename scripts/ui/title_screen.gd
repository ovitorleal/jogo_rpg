extends Control
## Tela de título provisória.
## Apenas apresentação: não contém regras nem estado de jogo.

const NEW_GAME_SCENE := "res://scenes/world/test_map.tscn"
const CONTINUE_PENDING_TOOLTIP := "Nenhum salvamento disponível (sistema de salvamento previsto para a Fase 6)."

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	var game_version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	_version_label.text = "v%s · Godot %s" % [game_version, Engine.get_version_info().string]

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.disabled = true
	_continue_button.tooltip_text = CONTINUE_PENDING_TOOLTIP
	# Fechar a aba é responsabilidade do navegador; "Sair" só faz sentido no desktop.
	_quit_button.visible = not OS.has_feature("web")
	_quit_button.pressed.connect(_on_quit_pressed)

	_status_label.text = ""
	_new_game_button.grab_focus()


func _on_new_game_pressed() -> void:
	var err := get_tree().change_scene_to_file(NEW_GAME_SCENE)
	if err != OK:
		_status_label.text = "Não foi possível iniciar o jogo (%s)." % error_string(err)
		push_error("Falha ao carregar %s: %s" % [NEW_GAME_SCENE, error_string(err)])


func _on_quit_pressed() -> void:
	get_tree().quit()
