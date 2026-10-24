extends "res://tests/base_test.gd"
## Verifica a configuração da Fase 0: renderer, pixel art, cena inicial e exportação Web.

const EXPORT_PRESETS_PATH := "res://export_presets.cfg"


func test_renderer_is_compatibility() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility",
			"Renderer deve ser Compatibility (WebGL 2)")


func test_pixel_art_uses_nearest_filter() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0,
			"Filtro padrão de texturas 2D deve ser Nearest")


func test_main_scene_loads() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_true(ResourceLoader.exists(path), "Cena principal deve existir: %s" % path)
	assert_true(load(path) is PackedScene, "Cena principal deve ser uma PackedScene")


func test_title_screen_initial_state() -> void:
	var scene: PackedScene = load("res://scenes/menus/title_screen.tscn")
	var title: Control = scene.instantiate()
	tree.root.add_child(title)
	await tree.process_frame

	var continue_button: Button = title.get_node("%ContinueButton")
	var status: Label = title.get_node("%StatusLabel")
	var version: Label = title.get_node("%VersionLabel")
	var expected_version: String = ProjectSettings.get_setting("application/config/version")

	assert_true(continue_button.disabled, "Continuar deve estar desabilitado sem save")
	assert_eq(status.text, "", "Status deve começar vazio")
	assert_true(version.text.begins_with("v%s" % expected_version), "Versão deve vir do project.godot")

	title.queue_free()
	await tree.process_frame


func test_credits_include_required_attributions() -> void:
	var scene: PackedScene = load("res://scenes/menus/title_screen.tscn")
	var title: Control = scene.instantiate()
	tree.root.add_child(title)
	await tree.process_frame
	var panel: Control = title.get_node("%CreditsPanel")
	assert_true(not panel.visible, "Créditos começam fechados")
	(title.get_node("%CreditsButton") as Button).pressed.emit()
	assert_true(panel.visible, "Botão Créditos abre o painel")
	var text := (title.get_node("%CreditsText") as RichTextLabel).get_parsed_text()
	assert_true(text.contains("System Reference Document 5.2") and text.contains("creativecommons.org/licenses/by/4.0"),
			"Atribuição CC BY 4.0 do SRD presente")
	assert_true(text.contains("não é um produto oficial"), "Aviso de produto não oficial")
	assert_true(text.contains("Godot Engine") and text.contains("MIT"), "Aviso de licença do Godot")
	(title.get_node("%CloseCreditsButton") as Button).pressed.emit()
	assert_true(not panel.visible, "Fechar oculta o painel")
	title.queue_free()
	await tree.process_frame


func test_new_game_scene_exists() -> void:
	var title_script: GDScript = load("res://scripts/ui/title_screen.gd")
	var path: String = title_script.get_script_constant_map().get("NEW_GAME_SCENE", "")
	assert_true(ResourceLoader.exists(path), "Cena de Novo jogo deve existir: %s" % path)
	assert_true(load(path) is PackedScene, "Cena de Novo jogo deve ser uma PackedScene")


func test_input_actions_exist() -> void:
	for action in [&"move_up", &"move_down", &"move_left", &"move_right", &"interact", &"character_sheet"]:
		assert_true(InputMap.has_action(action), "Ação de input ausente: %s" % action)
		if InputMap.has_action(action):
			assert_true(not InputMap.action_get_events(action).is_empty(), "Ação sem teclas: %s" % action)


func test_web_export_preset() -> void:
	var config := ConfigFile.new()
	assert_eq(config.load(EXPORT_PRESETS_PATH), OK, "export_presets.cfg deve carregar")
	assert_eq(config.get_value("preset.0", "platform", ""), "Web", "Preset 0 deve ser Web")
	assert_eq(config.get_value("preset.0", "export_path", ""), "exports/web/index.html", "Caminho de exportação")
	assert_eq(config.get_value("preset.0.options", "variant/thread_support", true), false,
			"Sem threads: evita exigir cabeçalhos COOP/COEP na hospedagem")
	assert_true(str(config.get_value("preset.0", "include_filter", "")).contains("data/*.json"),
			"Dados de conteúdo (JSON) devem entrar no pacote exportado")


func test_autoloads_are_available() -> void:
	assert_true(tree.root.has_node("Content"), "Autoload Content")
	assert_true(tree.root.has_node("PartyManager"), "Autoload PartyManager")
	var content: Node = tree.root.get_node("Content")
	assert_true(content.is_valid(), "Conteúdo carregado sem erros: %s" % str(content.registry.errors))
