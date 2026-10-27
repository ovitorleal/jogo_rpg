extends Control
## Tela de título provisória.
## Apenas apresentação: não contém regras nem estado de jogo.

const NEW_GAME_SCENE := "res://scenes/menus/character_creation.tscn"
const NO_SAVE_TOOLTIP := "Nenhum jogo salvo."
const OVERWRITE_WARNING := "Já existe um jogo salvo. O novo jogo vai substituí-lo no primeiro salvamento (o anterior fica como cópia de recuperação até o salvamento seguinte). Continuar?"
const NOT_PERSISTENT_WARNING := "Atenção: este navegador não está guardando dados permanentes (ex.: janela anônima). O progresso será perdido ao fechar a página."

## Atribuição exigida pela licença CC BY 4.0 do SRD 5.2 (texto oficial, não traduzir).
const SRD_ATTRIBUTION := "This work includes material from the System Reference Document 5.2 (\"SRD 5.2\") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode."
const NOT_OFFICIAL_NOTICE := "Este jogo não é um produto oficial de Dungeons & Dragons e não é afiliado à Wizards of the Coast."
const GODOT_NOTICE := "Feito com Godot Engine (licença MIT). Copyright (c) 2014-present Godot Engine contributors. Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur. Componentes de terceiros do motor: arquivo ENGINE_LICENSES.txt publicado junto do jogo."

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel
@onready var _version_label: Label = %VersionLabel
@onready var _credits_panel: PanelContainer = %CreditsPanel
@onready var _credits_text: RichTextLabel = %CreditsText
@onready var _close_credits_button: Button = %CloseCreditsButton

var _confirm_new_game: ConfirmationDialog


func _ready() -> void:
	var game_version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	_version_label.text = "v%s · Godot %s" % [game_version, Engine.get_version_info().string]

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_confirm_new_game = ConfirmationDialog.new()
	_confirm_new_game.title = "Novo jogo"
	_confirm_new_game.dialog_text = OVERWRITE_WARNING
	_confirm_new_game.dialog_autowrap = true
	_confirm_new_game.min_size = Vector2i(320, 0)
	_confirm_new_game.ok_button_text = "Começar novo jogo"
	_confirm_new_game.cancel_button_text = "Voltar"
	_confirm_new_game.confirmed.connect(_start_new_game)
	# A janela não herda o tema da tela: mesmo tamanho de letra do menu.
	var dialog_theme := Theme.new()
	dialog_theme.default_font_size = 10
	_confirm_new_game.theme = dialog_theme
	add_child(_confirm_new_game)
	_credits_button.pressed.connect(_on_credits_pressed)
	_close_credits_button.pressed.connect(_on_close_credits_pressed)
	# Fechar a aba é responsabilidade do navegador; "Sair" só faz sentido no desktop.
	_quit_button.visible = not OS.has_feature("web")
	_quit_button.pressed.connect(_on_quit_pressed)

	_credits_text.text = credits_text()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.x = 380
	refresh_save_status()
	if _continue_button.disabled:
		_new_game_button.grab_focus()
	else:
		_continue_button.grab_focus()


## Habilita "Continuar" se houver um salvamento válido e mostra o resumo (ou o problema).
func refresh_save_status() -> void:
	var found := SaveManager.peek()
	var lines := PackedStringArray()
	_continue_button.disabled = not found["ok"]
	if found["ok"]:
		var summary: Dictionary = found["state"].get("summary", {})
		var text := "%s · %s %s nível %d · %s" % [summary.get("name", "?"), summary.get("species", ""),
				summary.get("class", ""), int(summary.get("level", 1)), summary.get("place", "")]
		_continue_button.tooltip_text = text
		lines.append("Jogo salvo: %s" % text)
	else:
		_continue_button.tooltip_text = NO_SAVE_TOOLTIP
	if not str(found["message"]).is_empty():
		lines.append(found["message"])
	if not SaveManager.storage_persistent():
		lines.append(NOT_PERSISTENT_WARNING)
	_status_label.text = "\n".join(lines)


static func credits_text() -> String:
	return "\n\n".join(PackedStringArray([
		"[b]Créditos e licenças[/b]",
		"[b]Regras[/b]\n%s" % SRD_ATTRIBUTION,
		NOT_OFFICIAL_NOTICE,
		"[b]Motor[/b]\n%s" % GODOT_NOTICE,
		"[b]Arte e conteúdo[/b]\nArte original do projeto, desenhada por código. Aventura, diálogos e personagens originais. "
				+ "Código e conteúdo próprios: todos os direitos reservados (ver LICENSE.txt).",
	]))


func _unhandled_input(event: InputEvent) -> void:
	if _credits_panel.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_credits_pressed()


func _on_new_game_pressed() -> void:
	if SaveManager.has_save():
		_confirm_new_game.popup_centered()
		return
	_start_new_game()


func _start_new_game() -> void:
	var err := get_tree().change_scene_to_file(NEW_GAME_SCENE)
	if err != OK:
		_status_label.text = "Não foi possível iniciar o jogo (%s)." % error_string(err)
		push_error("Falha ao carregar %s: %s" % [NEW_GAME_SCENE, error_string(err)])


func _on_continue_pressed() -> void:
	var result := SaveManager.load_game()
	if not result["ok"]:
		_status_label.text = result["message"]
		refresh_save_status()
		return
	var err := get_tree().change_scene_to_file(result["scene"])
	if err != OK:
		_status_label.text = "Não foi possível abrir o local salvo (%s)." % error_string(err)


func _on_credits_pressed() -> void:
	_credits_panel.visible = true
	_close_credits_button.grab_focus()


func _on_close_credits_pressed() -> void:
	_credits_panel.visible = false
	_credits_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()
