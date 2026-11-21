extends "res://tests/base_test.gd"
## Combate mais vivo: opções do jogador (Settings), tremor de tela, cores de dano por tipo, partículas de impacto
## e de morte, e o interruptor do tremor no menu de pausa.

const TEST_PATH := "user://test_settings.cfg"

var _old_path := ""


func _settings() -> Node:
	return tree.root.get_node("Settings")


func _isolate() -> void:
	_old_path = _settings().path
	_settings().path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_settings().reset_to_defaults()


func _restore() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_settings().path = _old_path
	_settings().load_settings()


func test_settings_save_and_load() -> void:
	_isolate()
	var s := _settings()
	assert_true(s.screen_shake, "Tremor ligado por padrão")
	s.set_value("screen_shake", false)
	s.set_value("music_volume", 0.25)
	s.reset_to_defaults()
	assert_true(s.screen_shake, "Padrão de novo em memória")
	s.load_settings()
	assert_true(not s.screen_shake, "Tremor desligado lido do disco")
	assert_eq(snappedf(s.music_volume, 0.01), 0.25, "Volume lido do disco")
	_restore()


func test_shake_respects_the_switch_and_returns_home() -> void:
	var node := Control.new()
	tree.root.add_child(node)
	node.position = Vector2(10, 20)
	assert_true(not CombatFx.shake(node, 4.0, false), "Desligado: não treme")
	assert_eq(node.position, Vector2(10, 20), "Nem sai do lugar")
	assert_true(CombatFx.shake(node, 4.0, true, 0.1), "Ligado: treme")
	for i in 60:
		if not node.has_meta("shake_home"):
			break
		await tree.process_frame
	assert_eq(node.position, Vector2(10, 20), "Volta ao lugar no fim")
	node.queue_free()
	await tree.process_frame


func test_damage_colors_by_type() -> void:
	var fire := CombatFx.damage_color("fire")
	assert_true(fire != CombatFx.damage_color("cold"), "Fogo e frio têm cores diferentes")
	assert_true(fire != CombatFx.damage_color("slashing"), "Fogo e físico diferem")
	assert_eq(CombatFx.damage_color("slashing"), CombatFx.damage_color("piercing"), "Dano físico tem a mesma cor")
	assert_eq(CombatFx.damage_color("desconhecido"), CombatFx.damage_color("bludgeoning"), "Tipo desconhecido usa a cor física")


func test_particles_clean_themselves_up() -> void:
	var parent := Node2D.new()
	tree.root.add_child(parent)
	var fx := CombatFx.burst(parent, Vector2(5, 5), Color.ORANGE, "spark")
	assert_true(fx != null and fx.get_parent() == parent, "Faíscas criadas no lugar")
	assert_true(fx.emitting and fx.one_shot, "Uma rajada só")
	await tree.create_timer(fx.lifetime + 0.4).timeout
	assert_true(not is_instance_valid(fx), "Somem sozinhas")
	parent.queue_free()
	await tree.process_frame


func test_pause_menu_toggles_screen_shake() -> void:
	_isolate()
	var menu := PauseMenu.new()
	tree.root.add_child(menu)
	await tree.process_frame
	assert_true(menu.shake_toggle.button_pressed, "Interruptor mostra o tremor ligado")
	menu.shake_toggle.button_pressed = false
	assert_true(not _settings().screen_shake, "Desligar no menu desliga o tremor")
	menu.queue_free()
	await tree.process_frame
	_restore()
