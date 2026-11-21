extends "res://tests/base_test.gd"
## Áudio: efeitos e músicas gerados por código, barramentos Music/SFX que seguem as opções do jogador, música por
## lugar, silenciar (tecla M) e os controles do menu de pausa.

const TEST_PATH := "user://test_settings_audio.cfg"

var _old_path := ""


func _settings() -> Node:
	return tree.root.get_node("Settings")


func _audio() -> Node:
	return tree.root.get_node("AudioManager")


func _isolate() -> void:
	_old_path = _settings().path
	_settings().path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_settings().reset_to_defaults()
	_audio().apply_volumes()


func _restore() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_settings().path = _old_path
	_settings().load_settings()
	_audio().apply_volumes()


func test_every_sound_file_exists() -> void:
	await tree.process_frame  # os autoloads (Content, Settings) ficam prontos no 1º quadro
	var audio := _audio()
	for sfx: String in audio.SFX_NAMES:
		assert_true(ResourceLoader.exists(audio.sfx_path(sfx)), "Efeito existe: %s" % sfx)
	for track: String in audio.MUSIC_TRACKS:
		var path: String = audio.music_path(track)
		assert_true(ResourceLoader.exists(path), "Música existe: %s" % track)
		var stream := load(path) as AudioStreamWAV
		assert_true(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Música em laço: %s" % track)


func test_buses_exist() -> void:
	await tree.process_frame  # os autoloads (Content, Settings) ficam prontos no 1º quadro
	assert_true(AudioServer.get_bus_index(&"Music") >= 0, "Barramento Music")
	assert_true(AudioServer.get_bus_index(&"SFX") >= 0, "Barramento SFX")


func test_play_sfx_known_and_unknown() -> void:
	await tree.process_frame  # os autoloads (Content, Settings) ficam prontos no 1º quadro
	var audio := _audio()
	assert_true(audio.play_sfx("hit"), "Toca um efeito conhecido")
	assert_true(not audio.play_sfx("nao_existe"), "Recusa um efeito desconhecido")


func test_music_switches_and_repeats_without_restart() -> void:
	await tree.process_frame  # os autoloads (Content, Settings) ficam prontos no 1º quadro
	var audio := _audio()
	var before: String = audio.current_track
	assert_true(audio.play_music("village", 0.0), "Toca a música da vila")
	assert_eq(audio.current_track, "village", "Faixa atual")
	assert_true(not audio.play_music("village", 0.0), "Mesma faixa não recomeça")
	assert_true(not audio.play_music("nao_existe", 0.0), "Faixa desconhecida é recusada")
	assert_eq(audio.current_track, "village", "Faixa desconhecida não troca a atual")
	audio.play_music("", 0.0)
	assert_eq(audio.current_track, "", "Vazio para a música")
	if not before.is_empty():
		audio.play_music(before, 0.0)


func test_music_per_map_comes_from_data() -> void:
	await tree.process_frame  # os autoloads (Content, Settings) ficam prontos no 1º quadro
	var audio := _audio()
	var registry: ContentRegistry = tree.root.get_node("Content").registry
	assert_eq(str(registry.get_entry("map", "map.village").get("music")), "village", "Vila tem música calma")
	assert_eq(str(registry.get_entry("map", "map.forest_brook").get("music")), "forest", "Bosque: música da floresta")
	assert_eq(str(registry.get_entry("map", "map.clearing").get("music")), "forest", "Clareira: música da floresta")
	for id in registry.ids("map"):
		var track := str(registry.get_entry("map", id).get("music"))
		assert_true(audio.MUSIC_TRACKS.has(track), "Música do mapa %s existe" % id)


func test_bus_volumes_follow_settings_and_mute() -> void:
	await tree.process_frame  # os autoloads (Content, Settings) ficam prontos no 1º quadro
	_isolate()
	var s := _settings()
	var music_bus := AudioServer.get_bus_index(&"Music")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	var master := AudioServer.get_bus_index(&"Master")
	s.set_value("music_volume", 0.5)
	assert_eq(snappedf(AudioServer.get_bus_volume_db(music_bus), 0.1), snappedf(linear_to_db(0.5), 0.1),
			"Volume da música segue a opção")
	s.set_value("sfx_volume", 0.0)
	assert_true(AudioServer.is_bus_mute(sfx_bus), "Volume zero silencia os efeitos")
	s.set_value("sfx_volume", 1.0)
	assert_true(not AudioServer.is_bus_mute(sfx_bus), "Volume de volta")
	assert_true(not AudioServer.is_bus_mute(master), "Som ligado")
	_audio().toggle_mute()
	assert_true(s.muted, "Silenciar grava a opção")
	assert_true(AudioServer.is_bus_mute(master), "Silenciar corta tudo")
	_audio().toggle_mute()
	assert_true(not AudioServer.is_bus_mute(master), "Silenciar de novo devolve o som")
	_restore()


func test_m_key_toggles_mute() -> void:
	await tree.process_frame  # os autoloads (Content, Settings) ficam prontos no 1º quadro
	_isolate()
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.physical_keycode = KEY_M
	key.pressed = true
	_audio()._unhandled_input(key)
	assert_true(_settings().muted, "M silencia")
	_audio()._unhandled_input(key)
	assert_true(not _settings().muted, "M de novo devolve o som")
	_restore()


func test_buttons_click() -> void:
	await tree.process_frame  # os autoloads (Content, Settings) ficam prontos no 1º quadro
	var audio := _audio()
	var button := Button.new()
	tree.root.add_child(button)
	var before: int = audio.sfx_played
	button.pressed.emit()
	assert_eq(audio.last_sfx, "click", "Botão faz clique")
	assert_eq(audio.sfx_played, before + 1, "Um clique por aperto")
	button.queue_free()
	await tree.process_frame


func test_pause_menu_audio_controls() -> void:
	await tree.process_frame  # os autoloads (Content, Settings) ficam prontos no 1º quadro
	_isolate()
	var menu := PauseMenu.new()
	tree.root.add_child(menu)
	menu.music_slider.value = 0.3
	assert_eq(snappedf(_settings().music_volume, 0.01), 0.3, "Controle de música grava a opção")
	menu.sfx_slider.value = 0.6
	assert_eq(snappedf(_settings().sfx_volume, 0.01), 0.6, "Controle de efeitos grava a opção")
	menu.mute_toggle.button_pressed = true
	assert_true(_settings().muted, "Caixa de silenciar grava a opção")
	_audio().toggle_mute()
	assert_true(not menu.mute_toggle.button_pressed, "A caixa acompanha a tecla M")
	menu.queue_free()
	await tree.process_frame
	_restore()


func test_sounds_are_in_asset_catalog() -> void:
	await tree.process_frame  # os autoloads (Content, Settings) ficam prontos no 1º quadro
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_catalog.json"))
	var paths := {}
	for entry: Dictionary in catalog.get("assets", []):
		paths[str(entry.get("file_path"))] = true
	var audio := _audio()
	for sfx: String in audio.SFX_NAMES:
		assert_true(paths.has(audio.sfx_path(sfx)), "Catálogo tem %s" % sfx)
	for track: String in audio.MUSIC_TRACKS:
		assert_true(paths.has(audio.music_path(track)), "Catálogo tem a música %s" % track)
